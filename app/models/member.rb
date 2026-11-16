class Member < ApplicationRecord
  belongs_to :workspace
  has_one :user, dependent: :destroy
  has_many :group_memberships, dependent: :delete_all
  has_many :groups, through: :group_memberships
  has_many :channel_memberships, dependent: :delete_all
  has_many :channels, through: :channel_memberships

  validates :slack_user_id, presence: true, uniqueness: { scope: :workspace_id }
  validates :name, presence: true

  scope :people, -> { where(deleted: false, is_bot: false).where.not(tz: nil) }
  scope :colleagues, -> { people.where(guest: false) }
  scope :alphabetical, -> { order(Arel.sql("LOWER(name)")) }

  DEPARTED_NAME = "Former member".freeze
  MIN_QUIET_MINUTES = 60
  SCRUBBED = {
    name: DEPARTED_NAME, display_name: nil, avatar_url: nil, email: nil, tz: nil, tz_label: nil, tz_offset: nil,
    dnd_enabled: false, dnd_starts_at: nil, dnd_ends_at: nil, dnd_synced_at: nil
  }.freeze

  # Someone left the Slack org. Take them out of every group, end their own
  # account if they had one, and keep nothing personal: the row survives only
  # as an anonymous marker so the next roster sync doesn't re-import them.
  def depart!
    token = nil
    transaction do
      group_memberships.delete_all
      channel_memberships.delete_all
      token = user&.offboard!
      update!(SCRUBBED.merge(deleted: true))
    end
    Sources::Slack.new.revoke(token) if token.present? # a courtesy, after commit
  rescue Sources::Base::Error, Faraday::Error
    nil
  end

  # Full name first ("Kevin Ebaugh"); `name` already falls back to the
  # Slack handle when someone hasn't set one.
  # This person's time zone by name ("Pacific Time"), never their city.
  def zone_name(at = Time.current)
    Grid.generic_zone_name(tz_label) || (zone && Grid.zone_abbreviation(zone, at)) || tz
  end

  def label
    name.presence || display_name
  end

  def zone
    @zone ||= TZInfo::Timezone.get(tz) if tz.present?
  rescue TZInfo::InvalidTimezoneIdentifier
    nil
  end

  # The part of the day this person allows notifications: their Slack
  # "Working hours" (Preferences › Availability). Returns [from_minute, to_minute] in their
  # local time (may wrap past midnight), or nil when they have no schedule.
  def reachable_minutes
    return unless dnd_enabled && dnd_starts_at && dnd_ends_at && zone

    quiet_from = minute_of_day(dnd_starts_at)
    quiet_to = minute_of_day(dnd_ends_at)
    # Working hours of nearly all day (Slack's "12:00 AM to Midnight") say nothing.
    return if (quiet_to - quiet_from) % 1440 < MIN_QUIET_MINUTES

    [ quiet_to, quiet_from ]
  end

  private
    def minute_of_day(time)
      local = zone.to_local(time.utc)
      local.hour * 60 + local.min
    end
end
