class User < ApplicationRecord
  belongs_to :member
  has_many :board_visits, dependent: :delete_all

  encrypts :slack_user_token

  delegate :workspace, :label, :tz, :avatar_url, to: :member

  def local_today
    (member.zone || TZInfo::Timezone.get("Etc/UTC")).to_local(Time.current).to_date
  end

  CHANNELS_TTL = 1.hour

  # Granted when they signed in after channels arrived.
  def channels_granted?
    token_scopes.to_s.split(",").include?("channels:read")
  end

  def channels_stale?
    channels_synced_at.nil? || channels_synced_at < CHANNELS_TTL.ago
  end

  # Called on board loads; queues a refresh of their own channels when due.
  def refresh_my_channels_if_stale!
    SyncMyChannelsJob.perform_later(self) if channels_granted? && channels_stale? &&
      Rails.cache.write("user/#{id}/my-channels", true, expires_in: Workspace::FRESH_FOR, unless_exist: true)
  end

  # This person is in exactly these channels (Slack ids), among the ones we know.
  def import_my_channels!(slack_ids)
    known = workspace.channels.where(slack_channel_id: slack_ids).pluck(:id)
    transaction do
      ChannelMembership.where(member_id: member_id).where.not(channel_id: known).delete_all
      (known - ChannelMembership.where(member_id: member_id).pluck(:channel_id)).each { ChannelMembership.create!(channel_id: it, member_id:) }
      update_columns(channels_synced_at: Time.current)
    end
  end

  def refresh_tab_order!(handles, on:)
    update_columns(tab_order: handles, tab_order_on: on)
  end

  def forget_token!
    update!(slack_user_token: nil)
  end

  # Slack rejected this person's token. A deactivated account means they've
  # left the org; anything else (revoked, expired) just means sign in again.
  def handle_auth_failure!(error)
    error.message == "account_inactive" ? member.depart! : forget_token!
  end

  # Ends their account. Returns the token so the caller can revoke it once
  # the transaction commits.
  def offboard!
    slack_user_token.tap { destroy! }
  end
end
