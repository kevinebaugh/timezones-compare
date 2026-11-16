# A public Slack channel (e.g. #design), mirrored by name and size on roster
# syncs. Who's in it is fetched only when someone opens its board, or for the
# viewer's own channels, so big workspaces don't cost thousands of calls.
class Channel < ApplicationRecord
  KEY_PREFIX = "~" # never valid in Slack channel names or group handles
  MAX_MEMBERS = 2_000

  belongs_to :workspace
  has_many :channel_memberships, dependent: :delete_all
  has_many :members, through: :channel_memberships

  validates :slack_channel_id, :name, presence: true

  def self.key_for(name) = "#{KEY_PREFIX}#{name}"
  def key = self.class.key_for(name)

  def members_stale?
    members_synced_at.nil? || members_synced_at < Workspace::FRESH_FOR.ago
  end

  # Replace who's in the channel with what Slack says now.
  def import_members!(slack_ids)
    ids = workspace.members.where(deleted: false, slack_user_id: slack_ids).pluck(:id)
    transaction do
      channel_memberships.where.not(member_id: ids).delete_all
      (ids - channel_memberships.pluck(:member_id)).each { channel_memberships.create!(member_id: it) }
      update!(members_synced_at: Time.current)
    end
  end

  # Fetch members now if we've never seen them (the board needs them to
  # render), or in the background when they're just getting old.
  def ensure_members!(token_user:)
    return unless members_stale?
    return SyncChannelMembersJob.perform_later(self) if members_synced_at

    workspace.with_source_token(prefer: token_user) do |token|
      import_members!(Sources::Slack.new.channel_members(token, slack_channel_id, limit: MAX_MEMBERS))
    end
  rescue Sources::Base::Error, Faraday::Error => e
    Rails.logger.warn("Channel #{id} members failed: #{e.class}: #{e.message}")
    Rails.error.report(e, handled: true, severity: :warning, context: { workspace_id: workspace_id, channel_id: id })
  end
end
