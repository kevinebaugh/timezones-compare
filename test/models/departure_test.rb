require "test_helper"

class DepartureTest < ActiveSupport::TestCase
  setup { @workspace = workspaces(:acme) }

  def roster(*people) = stub_slack("users.list", ok: true, members: people)

  test "someone who leaves drops out of every board and their details are erased" do
    roster(slack_user("UKEV", name: "Kev", tz: "America/Los_Angeles"),
           slack_user("UNOOR", name: "Noor Aziz", tz: "Europe/London", deleted: true))
    @workspace.sync_roster!

    noor = members(:noor).reload
    assert noor.deleted?
    assert_equal Member::DEPARTED_NAME, noor.name
    assert_nil noor.tz
    assert_nil noor.avatar_url
    assert_not noor.dnd_enabled
    assert_empty noor.group_memberships
    assert_not_includes Board.everyone(users(:kev)).members, noor
  end

  test "someone who signed in and leaves loses their account" do
    sam_user = User.create!(member: members(:sam), slack_user_token: "xoxp-sam", last_signed_in_at: 2.days.ago)
    stub_slack("auth.revoke", ok: true)
    roster(slack_user("UKEV", name: "Kev", tz: "America/Los_Angeles"),
           slack_user("USAM", name: "Sam Lee", tz: "America/Los_Angeles", deleted: true))

    @workspace.sync_roster!

    assert_not User.exists?(sam_user.id)
    assert_requested :post, "https://slack.com/api/auth.revoke"
  end

  test "a deactivated token offboards that person right away" do
    kev_id = users(:kev).id
    stub_slack("users.list", ok: false, error: "account_inactive")
    assert_not @workspace.sync_roster!
    assert_not User.exists?(kev_id)
    assert members(:kev).reload.deleted?
  end

  test "a revoked token keeps the account" do
    stub_slack("users.list", ok: false, error: "token_revoked")
    @workspace.sync_roster!
    assert User.exists?(users(:kev).id)
    assert_nil users(:kev).reload.slack_user_token
  end

  test "a missing permission keeps the token" do
    stub_slack("users.list", ok: false, error: "missing_scope")
    assert_raises(Sources::Base::MissingScope) { @workspace.sync_roster! }
    assert_equal "xoxp-kev", users(:kev).reload.slack_user_token
  end

  test "people Slack already lists as gone are stored anonymously" do
    roster(slack_user("UGONE", name: "Long Gone", tz: "Asia/Tokyo", deleted: true))
    @workspace.sync_roster!
    gone = @workspace.members.find_by!(slack_user_id: "UGONE")
    assert_equal Member::DEPARTED_NAME, gone.name
    assert_nil gone.tz
  end

  test "guests and people from other orgs are marked as guests" do
    roster(slack_user("UGUEST", name: "Contractor", tz: "UTC", is_ultra_restricted: true),
           slack_user("UEXT", name: "Partner", tz: "UTC", team_id: "TOTHER"),
           slack_user("UNOOR", name: "Noor Aziz", tz: "Europe/London", team_id: "TACME"))
    @workspace.sync_roster!
    assert @workspace.members.find_by!(slack_user_id: "UGUEST").guest?
    assert @workspace.members.find_by!(slack_user_id: "UEXT").guest?
    assert_not members(:noor).reload.guest?
  end

  test "someone who comes back is restored" do
    members(:noor).depart!
    roster(slack_user("UNOOR", name: "Noor Aziz", tz: "Europe/London"))
    @workspace.sync_roster!
    noor = members(:noor).reload
    assert_not noor.deleted?
    assert_equal "Europe/London", noor.tz
  end
end
