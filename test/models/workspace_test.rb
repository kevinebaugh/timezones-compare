require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  setup { @workspace = workspaces(:acme) }

  test "sync_roster! imports people and updates existing ones" do
    stub_slack("users.list", ok: true, members: [
      slack_user("UKEV", name: "Kevin", tz: "America/New_York"),
      slack_user("UNEW", name: "New Person", tz: "Australia/Sydney")
    ])

    assert @workspace.sync_roster!
    assert_equal "America/New_York", members(:kev).reload.tz
    assert_equal "Australia/Sydney", @workspace.members.find_by!(slack_user_id: "UNEW").tz
    assert_not @workspace.reload.roster_stale?
  end

  test "a revoked token is discarded and the next signed-in person's is used" do
    sam = User.create!(member: members(:sam), slack_user_token: "xoxp-sam", last_signed_in_at: 1.day.ago)
    stub_request(:post, "https://slack.com/api/users.list")
      .with(headers: { "Authorization" => "Bearer xoxp-kev" })
      .to_return(body: { ok: false, error: "token_revoked" }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:post, "https://slack.com/api/users.list")
      .with(headers: { "Authorization" => "Bearer xoxp-sam" })
      .to_return(body: { ok: true, members: [] }.to_json, headers: { "Content-Type" => "application/json" })

    assert @workspace.sync_roster!
    assert_nil users(:kev).reload.slack_user_token
    assert_equal "xoxp-sam", sam.reload.slack_user_token
  end

  test "sync is a no-op when nobody has a token" do
    users(:kev).forget_token!
    assert_not @workspace.sync_roster!
  end

  test "sync_roster! mirrors Slack user groups, membership included" do
    leadership_id = groups(:leadership).id
    stub_slack("users.list", ok: true, members: [
      slack_user("UKEV", name: "Kev", tz: "America/Los_Angeles"),
      slack_user("USAM", name: "Sam Lee", tz: "America/Los_Angeles")
    ])
    stub_slack("usergroups.list", ok: true, usergroups: [
      { id: "SMOBILE", name: "Mobile Team", handle: "mobile-team", users: %w[UKEV USAM] },
      { id: "SNEW", name: "New Team", handle: "new-team", users: %w[UKEV UNKNOWN] },
      { id: "SGONE", name: "Old", handle: "old", users: %w[UKEV], date_delete: 1_700_000_000 }
    ])

    @workspace.sync_roster!

    assert_equal [ "Mobile Team", "New Team" ], @workspace.groups.by_name.pluck(:name)
    assert_equal %w[Kev Sam\ Lee], groups(:platform).reload.members.map(&:name).sort
    assert_equal %w[Kev], @workspace.groups.find_by!(handle: "new-team").members.map(&:name)
    assert_not Group.exists?(leadership_id), "no longer in Slack, removed here"
  end

  test "without usergroups:read, existing groups are left alone" do
    stub_slack("users.list", ok: true, members: [ slack_user("UKEV", name: "Kev", tz: "America/Los_Angeles") ])
    stub_slack("usergroups.list", ok: false, error: "missing_scope")
    assert @workspace.sync_roster!
    assert Group.exists?(groups(:leadership).id)
  end

  test "sync_availability! stores everyone's notification schedule in one batched call" do
    stub_slack("dnd.teamInfo", ok: true, users: {
      "UNOOR" => { dnd_enabled: true, next_dnd_start_ts: Time.utc(2026, 10, 16, 21).to_i, next_dnd_end_ts: Time.utc(2026, 10, 17, 7).to_i }
    })

    assert @workspace.sync_availability!

    assert_equal [ 8 * 60, 22 * 60 ], members(:noor).reload.reachable_minutes # BST: quiet 22:00–08:00 local
    assert_requested :post, "https://slack.com/api/dnd.teamInfo", times: 1
    assert_not_requested :post, "https://slack.com/api/users.getPresence"
  end
end
