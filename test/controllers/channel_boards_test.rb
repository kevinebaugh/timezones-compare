require "test_helper"

class ChannelBoardsTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:acme)
    @workspace.update!(roster_synced_at: Time.current, availability_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
    users(:kev).update!(token_scopes: Sources::Slack::USER_SCOPES.join(","), channels_synced_at: Time.current)
    @design = @workspace.channels.create!(slack_channel_id: "CDESIGN", name: "design", num_members: 2)
    @random = @workspace.channels.create!(slack_channel_id: "CRANDOM", name: "random", num_members: 5, members_synced_at: Time.current)
    @design.channel_memberships.create!(member: members(:kev))
  end

  test "the menu sorts everything else into your channels, groups and channels, marked # and 👥" do
    get board_path("everyone")
    assert_select ".board-tabs > .groups-menu > summary.tabs-more", I18n.t("boards.more")
    headings = css_select(".groups-heading:not([data-section='your_tabs'])").map(&:text)
    assert_equal [ I18n.t("boards.your_channels_heading"), I18n.t("boards.groups_heading"), I18n.t("boards.channels_heading"), I18n.t("boards.people_heading") ], headings
    assert_select ".group-item[data-section='your_channels']", /#\s*design/
    assert_select ".group-item[data-section='channels']", /#\s*random\s*5/m
    assert_select ".group-item[data-section='channels'] .group-count[title='5 people'][aria-label='5 people']", "5"
    assert_select ".group-item[data-section='groups']", /👥\s*Leadership/
    assert_select ".groups-reconnect", 0
  end

  test "opening a channel loads its members, and a channel I'm in becomes a tab" do
    stub_slack("conversations.members", ok: true, members: %w[UKEV UNOOR])
    get board_path("~design")
    assert_response :success
    assert_select ".board-tabs > a[aria-current='page']", /#\s*design/
    assert_select ".tz-row", 2
    assert_select "section", /#{Regexp.escape(I18n.t("boards.channel_note", name: "design"))}/

    get board_path("everyone")
    assert_select ".board-tabs > a[href^='/boards/~design']", /#\s*design/
    assert_select ".group-item[data-section='your_channels']", 0
  end

  test "a channel I'm not in opens as a visiting tab and never joins my tabs" do
    get board_path("~random")
    assert_select ".board-tabs > a.is-visiting", /#\s*random/
    assert_select "section", /#{Regexp.escape(I18n.t("boards.not_in_channel"))}/

    get board_path("everyone")
    assert_select ".board-tabs > a", text: /random/, count: 0
  end

  test "signed in before channels: a gentle prompt to reconnect, and no channels fetched" do
    users(:kev).update!(token_scopes: "users:read,users:read.email,dnd:read,usergroups:read")
    get board_path("everyone")
    assert_select ".groups-reconnect", /#{Regexp.escape(I18n.t("boards.reconnect_channels"))}/
    assert_select ".groups-reconnect form[action='/auth/slack']"
  end

  test "unknown channels are not found" do
    get board_path("~nope")
    assert_response :not_found
  end

  test "channels are listed biggest first" do
    @workspace.channels.create!(slack_channel_id: "CBIG", name: "announcements", num_members: 40)
    get board_path("everyone")
    assert_equal %w[announcements random], css_select(".group-item[data-section='channels']").map { it.text[/#\s*(\S+)/, 1] }
  end
end
