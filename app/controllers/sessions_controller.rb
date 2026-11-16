class SessionsController < ApplicationController
  skip_before_action :require_user, only: %i[start callback demo]

  # Plenty for a person adding a few workspaces; too few to hammer Slack's
  # token endpoint or cycle through accounts from one address.
  rate_limit to: 10, within: 1.minute, only: %i[start callback demo], with: -> { too_many_attempts }
  rate_limit to: 30, within: 1.minute, only: :switch, name: "switch", with: -> { too_many_attempts }

  def start
    source = Sources::Slack.new
    return redirect_to(root_path, alert: t("sessions.not_configured")) unless source.configured?

    session[:oauth_state] = SecureRandom.hex(24)
    redirect_to source.authorize_url(state: session[:oauth_state], redirect_uri: slack_callback_url),
                allow_other_host: true
  end

  def callback
    expected_state = session.delete(:oauth_state)
    return_to = session.delete(:return_to)
    if params[:error].present?
      return redirect_to(root_path, alert: t("sessions.cancelled"))
    end
    unless expected_state.present? && ActiveSupport::SecurityUtils.secure_compare(expected_state, params[:state].to_s)
      return redirect_to(root_path, alert: t("sessions.expired"))
    end

    source = Sources::Slack.new
    result = source.exchange(code: params.require(:code), redirect_uri: slack_callback_url)
    if guest?(result)
      revoke_quietly(source, result.fetch(:token)) # nothing is stored; hand the token back
      return redirect_to(root_path, alert: t("sessions.guests_not_allowed"))
    end

    user = import_sign_in(result)
    sign_in(user)
    session[:return_to] = return_to if return_to
    return redirect_to(setup_path) if user.workspace.needs_first_sync?

    user.workspace.refresh_if_stale!
    redirect_to after_sign_in_path
  rescue Sources::Base::Error => e
    Rails.logger.warn("Slack sign-in failed: #{e.message}")
    Rails.error.report(e, handled: true, severity: :warning, context: { step: "sign-in" })
    redirect_to root_path, alert: t("sessions.failed")
  end

  def demo
    return head(:not_found) unless DemoMode.enabled?

    workspace = DemoMode.workspace
    member = workspace.members.find_by(id: params[:member_id]) || workspace.members.alphabetical.first
    user = User.find_or_create_by!(member: member)
    sign_in(user)
    redirect_to board_path(Board::EVERYONE)
  end

  def switch
    id = params[:user_id].to_i
    return head(:not_found) unless signed_in_ids.include?(id)

    session[:user_id] = id
    redirect_to board_path(Board::EVERYONE)
  end

  # Signs out of the active workspace; others stay signed in.
  def destroy
    left = Current.user.workspace.name
    remaining = signed_in_ids - [ Current.user.id ]
    return destroy_all if remaining.empty?

    session[:user_ids] = remaining
    session[:user_id] = remaining.last
    redirect_to board_path(Board::EVERYONE), notice: t("sessions.signed_out_of", workspace: left)
  end

  def destroy_all
    reset_session
    redirect_to root_path, notice: t("sessions.signed_out")
  end

  private
    # Slack guests (single- and multi-channel) and people from other orgs see
    # only some of a workspace in Slack, so they can't sign in here, where
    # boards show the whole workspace.
    def revoke_quietly(source, token)
      source.revoke(token)
    rescue Sources::Base::Error, Faraday::Error
      nil
    end

    def guest?(result)
      person = result.fetch(:person)
      team_id = result.dig(:workspace, :external_id)
      person[:guest] == true || (person[:team_id].present? && person[:team_id] != team_id)
    end

    def too_many_attempts
      redirect_to root_path, alert: "Too many sign-in attempts. Try again in a minute.", status: :see_other
    end

    def import_sign_in(result)
      ActiveRecord::Base.transaction do
        ws = result.fetch(:workspace)
        workspace = Workspace.find_or_initialize_by(slack_team_id: ws.fetch(:external_id))
        workspace.update!(name: ws[:name].presence || workspace.name || "Slack", domain: ws[:domain])

        member = workspace.import_person(result.fetch(:person))
        user = User.find_or_initialize_by(member: member)
        user.update!(slack_user_token: result.fetch(:token), token_scopes: result[:scopes])
        user
      end
    end
end
