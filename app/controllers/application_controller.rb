class ApplicationController < ActionController::Base
  include Localization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Link preview fetchers are let through: Apple's (iMessage) poses as Safari 9
  # and would otherwise get the "unsupported browser" page instead of the preview.
  allow_browser versions: :modern, unless: :link_preview_bot?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :resume_session
  before_action :require_user

  helper_method :signed_in?

  MAX_ACCOUNTS = 5

  LINK_PREVIEW_BOTS = /facebookexternalhit|Facebot|Twitterbot|Slackbot|LinkedInBot|Discordbot|WhatsApp|TelegramBot|Applebot|Googlebot|bingbot|redditbot|Embedly|SkypeUriPreview|Teams/i

  private
    def link_preview_bot?
      request.user_agent.to_s.match?(LINK_PREVIEW_BOTS)
    end

    # The encrypted session cookie remembers every workspace this browser has
    # signed into (user_ids) and which one is active (user_id). Accounts whose
    # person has left the Slack org are dropped.
    def resume_session
      ids = signed_in_ids
      return if ids.empty?

      users = User.joins(:member).includes(member: :workspace)
                  .where(id: ids, members: { deleted: false, guest: false }).index_by(&:id)
      valid = ids.select { users.key?(it) }
      return reset_session if valid.empty?

      session[:user_ids] = valid
      session[:user_id] = valid.first unless valid.include?(session[:user_id])
      Current.user = users.fetch(session[:user_id])
      Current.accounts = valid.map { users.fetch(it) }
      # Ids only, for grouping errors by person and workspace; never names or emails.
      Rails.error.set_context(user_id: Current.user.id, workspace_id: Current.user.member.workspace_id)
    end

    # Back to a shared moment (/t/...) if that's where sign-in started; only
    # those paths, so this can't be turned into an open redirect.
    def after_sign_in_path
      path = session.delete(:return_to).to_s
      path.match?(%r{\A/t/\d+(\?[^\s]*)?\z}) ? path : board_path(Board::EVERYONE)
    end

    def signed_in_ids
      Array(session[:user_ids]).presence || Array(session[:user_id])
    end

    def require_user
      redirect_to root_path unless signed_in?
    end

    def signed_in?
      Current.user.present?
    end

    def sign_in(user)
      others = signed_in_ids - [ user.id ]
      reset_session # fresh session id on every sign-in
      session[:user_ids] = (others + [ user.id ]).last(MAX_ACCOUNTS)
      session[:user_id] = user.id
      user.update!(last_signed_in_at: Time.current)
      Current.user = user
    end
end
