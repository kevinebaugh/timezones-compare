# Which public channels this person is in, with their own token: one cheap
# call, so their channels can be offered as boards.
class SyncMyChannelsJob < ApplicationJob
  queue_as :default

  def perform(user)
    return if user.slack_user_token.blank?

    ids = Sources::Slack.new.my_channels(user.slack_user_token)
    user.import_my_channels!(ids)
  rescue Sources::Base::MissingScope
    user.update_columns(channels_synced_at: Time.current) # signed in before channels; nothing to do until they reconnect
  rescue Sources::Base::AuthError => e
    user.handle_auth_failure!(e)
  end
end
