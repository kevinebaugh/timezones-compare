require "test_helper"

class ChannelTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @workspace = workspaces(:acme)
    @kev = users(:kev)
  end

  def design = @workspace.channels.find_or_create_by!(slack_channel_id: "CDESIGN") { it.name = "design"; it.num_members = 3 }

  test "roster sync mirrors public channels by name and size, and drops archived ones" do
    gone = @workspace.channels.create!(slack_channel_id: "COLD", name: "old", num_members: 1)
    stub_slack("users.list", ok: true, members: [ slack_user("UKEV", name: "Kev", tz: "America/Los_Angeles") ])
    stub_slack("conversations.list", ok: true, channels: [ { id: "CDESIGN", name: "design", num_members: 3 } ])

    @workspace.sync_roster!
    assert_equal [ [ "design", 3 ] ], @workspace.channels.pluck(:name, :num_members)
    assert_not Channel.exists?(gone.id)
  end

  test "without channels:read, the channel list is left alone" do
    design
    stub_slack("users.list", ok: true, members: [ slack_user("UKEV", name: "Kev", tz: "America/Los_Angeles") ])
    assert @workspace.sync_roster!
    assert_equal 1, @workspace.channels.count
  end

  test "a channel's members load the first time its board is opened, then refresh in the background" do
    stub_slack("conversations.members", ok: true, members: %w[UKEV UNOOR UNOBODY])
    design.ensure_members!(token_user: @kev)
    assert_equal [ "Kev", "Noor Aziz" ], design.reload.members.map(&:name).sort
    assert_not design.members_stale?

    travel 10.minutes do
      assert_enqueued_with(job: SyncChannelMembersJob) { design.ensure_members!(token_user: @kev) }
    end
  end

  test "my own channels come from my token, among channels we know" do
    design
    stub_slack("users.conversations", ok: true, channels: [ { id: "CDESIGN" }, { id: "CUNKNOWN" } ])
    SyncMyChannelsJob.perform_now(@kev)
    assert_equal [ "design" ], members(:kev).channels.pluck(:name)
    assert_not @kev.reload.channels_stale?
  end

  test "leaving Slack removes someone from every channel" do
    design.channel_memberships.create!(member: members(:noor))
    members(:noor).depart!
    assert_empty design.reload.members
  end
end
