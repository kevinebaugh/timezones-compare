module Sources
  class Slack < Base
    API = "https://slack.com/api/"
    USER_SCOPES = %w[users:read users:read.email dnd:read usergroups:read channels:read].freeze
    MAX_CHANNELS = 1_000
    AUTH_ERRORS = %w[invalid_auth not_authed token_revoked token_expired account_inactive].freeze
    SCOPE_ERRORS = %w[missing_scope not_allowed_token_type].freeze
    DND_BATCH = 50

    def initialize(client_id: ENV["SLACK_CLIENT_ID"], client_secret: ENV["SLACK_CLIENT_SECRET"])
      @client_id = client_id
      @client_secret = client_secret
    end

    def configured?
      @client_id.present? && @client_secret.present?
    end

    def authorize_url(state:, redirect_uri:)
      query = { client_id: @client_id, user_scope: USER_SCOPES.join(","), redirect_uri:, state: }
      "https://slack.com/oauth/v2/authorize?#{query.to_query}"
    end

    def exchange(code:, redirect_uri:)
      body = call("oauth.v2.access", nil, code:, redirect_uri:, client_id: @client_id, client_secret: @client_secret)
      authed = body.fetch("authed_user")
      token = authed.fetch("access_token")
      auth = call("auth.test", token)
      person = call("users.info", token, user: authed.fetch("id")).fetch("user")

      {
        token:,
        scopes: authed["scope"],
        workspace: {
          external_id: body.dig("team", "id"),
          name: body.dig("team", "name") || auth["team"],
          domain: URI(auth["url"].to_s).host.to_s.delete_suffix(".slack.com").presence
        },
        person: normalize(person)
      }
    end

    def roster(token)
      people = []
      cursor = nil
      loop do
        body = call("users.list", token, limit: 200, cursor:)
        people.concat(body.fetch("members").map { normalize(it) })
        cursor = body.dig("response_metadata", "next_cursor").presence
        break unless cursor
      end
      people
    end

    def quiet_hours(token, external_ids)
      external_ids.each_slice(DND_BATCH).each_with_object({}) do |ids, result|
        users = call("dnd.teamInfo", token, users: ids.join(",")).fetch("users", {})
        users.each do |id, info|
          result[id] = {
            enabled: info["dnd_enabled"] == true,
            starts_at: timestamp(info["next_dnd_start_ts"]),
            ends_at: timestamp(info["next_dnd_end_ts"])
          }
        end
      end
    end


    # Every active user group, with its members. One call.
    def groups(token)
      call("usergroups.list", token, include_users: true).fetch("usergroups", [])
        .reject { it["date_delete"].to_i.positive? }
        .map do |group|
          { external_id: group.fetch("id"), name: group["name"].presence || group["handle"],
            handle: group["handle"].presence || group["id"], member_ids: group.fetch("users", []),
            updated_at: timestamp(group["date_update"]) }
        end
    end

    # Public, unarchived channels by name and size; the biggest first, capped.
    def channels(token)
      list = []
      cursor = nil
      loop do
        body = call("conversations.list", token, types: "public_channel", exclude_archived: true, limit: 1000, cursor:)
        list.concat(body.fetch("channels", []).map { { external_id: it.fetch("id"), name: it.fetch("name"), num_members: it["num_members"].to_i } })
        cursor = body.dig("response_metadata", "next_cursor").presence
        break if cursor.nil? || list.size >= MAX_CHANNELS * 3
      end
      list.sort_by { -it[:num_members] }.first(MAX_CHANNELS)
    end

    # Slack user ids in one channel, up to limit.
    def channel_members(token, channel_id, limit:)
      ids = []
      cursor = nil
      loop do
        body = call("conversations.members", token, channel: channel_id, limit: 1000, cursor:)
        ids.concat(body.fetch("members", []))
        cursor = body.dig("response_metadata", "next_cursor").presence
        break if cursor.nil? || ids.size >= limit
      end
      ids.first(limit)
    end

    # Slack ids of the public channels the token's own person is in.
    def my_channels(token)
      ids = []
      cursor = nil
      loop do
        body = call("users.conversations", token, types: "public_channel", exclude_archived: true, limit: 1000, cursor:)
        ids.concat(body.fetch("channels", []).map { it.fetch("id") })
        cursor = body.dig("response_metadata", "next_cursor").presence
        break if cursor.nil? || ids.size >= MAX_CHANNELS
      end
      ids
    end

    def revoke(token)
      call("auth.revoke", token)
    rescue AuthError
      nil
    end

    private
      def normalize(user)
        profile = user["profile"] || {}
        {
          external_id: user.fetch("id"),
          name: user["real_name"].presence || profile["real_name"].presence || user["name"],
          display_name: profile["display_name"].presence,
          avatar_url: profile["image_72"],
          email: profile["email"].presence,
          tz: user["tz"],
          tz_label: user["tz_label"],
          tz_offset: user["tz_offset"],
          deleted: user["deleted"] == true,
          is_bot: user["is_bot"] == true || user["id"] == "USLACKBOT",
          # Single- and multi-channel guests, and people from other orgs.
          guest: [ "is_restricted", "is_ultra_restricted", "is_stranger" ].any? { user[it] == true },
          team_id: user["team_id"]
        }
      end

      def timestamp(value)
        Time.at(value.to_i).utc if value.to_i.positive?
      end

      def call(method, token, params = {})
        response = connection.post(method) do |req|
          req.headers["Authorization"] = "Bearer #{token}" if token
          req.body = params.compact
        end

        raise RateLimited.new(response.headers["retry-after"].to_i.nonzero? || 30) if response.status == 429

        body = response.body.is_a?(Hash) ? response.body : JSON.parse(response.body.to_s)
        return body if body["ok"]

        error = body["error"].to_s
        raise AuthError, error if AUTH_ERRORS.include?(error)
        raise MissingScope, error if SCOPE_ERRORS.include?(error)
        raise Error, "Slack #{method} failed: #{error.presence || response.status}"
      end

      def connection
        @connection ||= Faraday.new(url: API) do |f|
          f.request :url_encoded
          f.response :json, content_type: /\bjson\z/
          f.options.timeout = 15
          f.options.open_timeout = 5
        end
      end
  end
end
