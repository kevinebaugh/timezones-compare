# Refreshes who's in one channel, after someone opened its board.
class SyncChannelMembersJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(channel) { "channel-#{channel.id}" }

  def perform(channel)
    return unless channel.members_stale?

    channel.workspace.with_source_token do |token|
      channel.import_members!(Sources::Slack.new.channel_members(token, channel.slack_channel_id, limit: Channel::MAX_MEMBERS))
    end
  end
end
