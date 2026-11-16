module Sources
  # Where people and their time zones come from. Slack is the only source in
  # v1; see docs/sources.md for what a new source needs to implement.
  #
  # Every method returns plain hashes so models never depend on a provider's
  # response shape. A person looks like:
  #
  #   { external_id:, name:, display_name:, avatar_url:, email:, tz:, tz_label:,
  #     tz_offset:, deleted:, is_bot:, guest:, team_id: }
  #
  # `guest` marks people outside the org's regular membership (guests,
  # contractors, other companies). They're left off the Everyone board.
  class Base
    class Error < StandardError; end
    class AuthError < Error; end      # token revoked or expired: discard it
    class MissingScope < Error; end   # token works but wasn't granted this permission

    class RateLimited < Error
      attr_reader :retry_after

      def initialize(retry_after)
        @retry_after = retry_after
        super("rate limited, retry after #{retry_after}s")
      end
    end

    # URL to send the browser to for sign-in.
    def authorize_url(state:, redirect_uri:) = raise(NotImplementedError)

    # Trade the OAuth code for { token:, scopes:, workspace: {...}, person: {...} }.
    def exchange(code:, redirect_uri:) = raise(NotImplementedError)

    # Every person visible to the token's owner.
    def roster(token) = raise(NotImplementedError)

    # { external_id => { enabled:, starts_at:, ends_at: } } quiet-hours schedule.
    def quiet_hours(token, external_ids) = {}


    # Teams the source knows about, each shown as a board to its members.
    #   [{ external_id:, name:, handle:, member_ids: [external_id, ...], updated_at: }]
    def groups(token) = []

    # Public channels and who's in them; nothing for sources without channels.
    def channels(token) = []
    def channel_members(token, channel_id, limit:) = []
    def my_channels(token) = []
  end
end
