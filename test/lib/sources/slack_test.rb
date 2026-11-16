require "test_helper"

class Sources::SlackTest < ActiveSupport::TestCase
  setup { @slack = Sources::Slack.new(client_id: "cid", client_secret: "secret") }

  test "authorize_url asks only for user scopes" do
    query = Rack::Utils.parse_query(URI(@slack.authorize_url(state: "s", redirect_uri: "https://x.test/cb")).query)
    assert_equal "users:read,users:read.email,dnd:read,usergroups:read,channels:read", query["user_scope"]
    assert_nil query["scope"], "no bot scopes"
    assert_equal "s", query["state"]
  end

  test "roster follows pagination and normalizes people" do
    stub_request(:post, "https://slack.com/api/users.list")
      .with(body: hash_including("cursor" => "next"))
      .to_return(body: { ok: true, members: [ slack_user("U2", name: "Bo", tz: "Asia/Tokyo") ],
                         response_metadata: { next_cursor: "" } }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:post, "https://slack.com/api/users.list")
      .with { |req| !req.body.include?("cursor=") }
      .to_return(body: { ok: true, members: [ slack_user("U1", name: "Al", tz: "Europe/Paris"),
                                              slack_user("USLACKBOT", name: "Slackbot", tz: nil) ],
                         response_metadata: { next_cursor: "next" } }.to_json, headers: { "Content-Type" => "application/json" })

    people = @slack.roster("xoxp")
    assert_equal %w[U1 USLACKBOT U2], people.map { it[:external_id] }
    assert_equal "Europe/Paris", people.first[:tz]
    assert people.second[:is_bot]
  end

  test "quiet_hours converts timestamps" do
    stub_slack("dnd.teamInfo", ok: true, users: { "U1" => { dnd_enabled: true, next_dnd_start_ts: 1_760_565_600, next_dnd_end_ts: 1_760_601_600 } })
    result = @slack.quiet_hours("xoxp", [ "U1" ])
    assert result["U1"][:enabled]
    assert_equal Time.at(1_760_565_600).utc, result["U1"][:starts_at]
  end

  test "groups lists active user groups with their members" do
    stub_slack("usergroups.list", ok: true, usergroups: [
      { id: "S1", name: "Mobile Team", handle: "mobile-team", users: %w[U1 U2] },
      { id: "S2", name: "Old", handle: "old", users: [], date_delete: 1_700_000_000 }
    ])
    assert_equal [ { external_id: "S1", name: "Mobile Team", handle: "mobile-team", member_ids: %w[U1 U2], updated_at: nil } ],
                 @slack.groups("xoxp")
  end

  test "revoked tokens raise AuthError" do
    stub_slack("users.list", ok: false, error: "token_revoked")
    assert_raises(Sources::Base::AuthError) { @slack.roster("xoxp") }
  end

  test "429 raises RateLimited with retry-after" do
    stub_slack("users.list", { ok: false }, status: 429, headers: { "Retry-After" => "7" })
    error = assert_raises(Sources::Base::RateLimited) { @slack.roster("xoxp") }
    assert_equal 7, error.retry_after
  end

  test "channels lists public channels by size, following pagination" do
    stub_request(:post, "https://slack.com/api/conversations.list").with(body: hash_including("cursor" => "next"))
      .to_return(body: { ok: true, channels: [ { id: "C2", name: "design", num_members: 9 } ], response_metadata: { next_cursor: "" } }.to_json,
                 headers: { "Content-Type" => "application/json" })
    stub_request(:post, "https://slack.com/api/conversations.list").with { |req| !req.body.include?("cursor=") }
      .to_return(body: { ok: true, channels: [ { id: "C1", name: "general", num_members: 40 }, { id: "C3", name: "quiet", num_members: 2 } ],
                         response_metadata: { next_cursor: "next" } }.to_json, headers: { "Content-Type" => "application/json" })

    assert_equal %w[general design quiet], @slack.channels("xoxp").map { it[:name] }
  end

  test "channel_members and my_channels return Slack ids" do
    stub_slack("conversations.members", ok: true, members: %w[U1 U2 U3])
    stub_slack("users.conversations", ok: true, channels: [ { id: "C1" }, { id: "C2" } ])
    assert_equal %w[U1 U2], @slack.channel_members("xoxp", "C1", limit: 2)
    assert_equal %w[C1 C2], @slack.my_channels("xoxp")
  end
end
