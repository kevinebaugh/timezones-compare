ENV["RAILS_ENV"] ||= "test"
ENV["SLACK_CLIENT_ID"] ||= "test-client-id"
ENV["SLACK_CLIENT_SECRET"] ||= "test-client-secret"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

module SlackStubs
  def stub_slack(method, response = nil, status: 200, headers: {}, **fields)
    response ||= fields
    stub_request(:post, "https://slack.com/api/#{method}")
      .to_return(status:, body: response.to_json, headers: { "Content-Type" => "application/json" }.merge(headers))
  end

  SLACK_TZ_LABELS = {
    "America/Los_Angeles" => "Pacific Daylight Time", "Europe/London" => "British Summer Time",
    "Asia/Tokyo" => "Japan Standard Time", "Asia/Kolkata" => "India Standard Time"
  }.freeze

  def slack_user(id, name:, tz:, **extra)
    { "id" => id, "name" => name.downcase, "real_name" => name, "tz" => tz, "tz_label" => SLACK_TZ_LABELS[tz],
      "tz_offset" => 0, "deleted" => false, "is_bot" => false,
      "profile" => { "display_name" => "", "image_72" => "https://avatars.test/#{id}.png" } }.merge(extra.stringify_keys)
  end
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
    include SlackStubs

    # Revoking a departed person's token is a courtesy call; allow it everywhere.
    # Group sync defaults to "permission not granted", which leaves groups as-is;
    # tests about groups stub usergroups.list themselves.
    setup do
      stub_slack("auth.revoke", ok: true)
      stub_slack("usergroups.list", ok: false, error: "missing_scope")
      # Channels likewise default to "not granted"; channel tests stub these.
      stub_slack("conversations.list", ok: false, error: "missing_scope")
      stub_slack("users.conversations", ok: false, error: "missing_scope")
      stub_slack("conversations.members", ok: false, error: "missing_scope")
    end
  end
end

class ActionDispatch::IntegrationTest
  # Runs the real OAuth round trip against stubbed Slack responses.
  def sign_in_via_slack(user_id: "UKEV", name: "Kev", tz: "America/Los_Angeles", team_id: "TACME", team_name: "Acme", token: "xoxp-new", **profile)
    post slack_sign_in_path
    state = Rack::Utils.parse_query(URI(response.location).query)["state"]

    stub_slack("oauth.v2.access", ok: true, team: { id: team_id, name: team_name },
               authed_user: { id: user_id, scope: "users:read,dnd:read", access_token: token, token_type: "user" })
    stub_slack("auth.test", ok: true, url: "https://acme.slack.com/", team: "Acme", user_id: user_id)
    stub_slack("users.info", ok: true, user: slack_user(user_id, name:, tz:, **profile))

    get slack_callback_path(code: "abc", state:)
  end
end
