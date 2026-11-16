class Workspace < ApplicationRecord
  has_many :members, dependent: :destroy
  has_many :users, through: :members
  has_many :groups, dependent: :destroy
  has_many :channels, dependent: :destroy

  validates :slack_team_id, presence: true, uniqueness: true
  validates :name, presence: true

  # Data older than this is refreshed (in the background) when someone opens
  # a board. One refresh per workspace per window, however many people look.
  FRESH_FOR = 5.minutes
  AVAILABILITY_TTL = FRESH_FOR
  ROSTER_TTL = FRESH_FOR
  MAX_SCHEDULE_LOOKUPS = 500  # notification schedules come 50 people per call

  # Users whose Slack tokens can be borrowed for background syncs, freshest first.
  def token_holders
    # Guests see only part of the workspace, so their tokens never sync it.
    users.where(members: { guest: false }).where.not(slack_user_token: nil).order(last_signed_in_at: :desc)
  end

  # Yields a working token from whoever signed in most recently. Tokens Slack
  # rejects are discarded and the next person's is tried. Returns nil when
  # nobody in the workspace has a usable token.
  def with_source_token(prefer: nil)
    holders = token_holders.to_a
    holders.unshift(holders.delete(prefer)) if prefer && holders.include?(prefer)
    holders.each do |user|
      return yield(user.slack_user_token)
    rescue Sources::Base::AuthError => e
      user.handle_auth_failure!(e)
    end
    nil
  end

  # Workspaces opened within this long get the hourly refresh; quieter ones
  # are refreshed daily, which still lands departures within a day.
  ACTIVE_FOR = 14.days

  scope :with_token_holders, -> { where(id: User.where.not(slack_user_token: nil).joins(:member).select("members.workspace_id")) }

  # Called on every board load and sign-in; cheap when nothing is due.
  def refresh_if_stale!
    touch_viewed
    SyncRosterJob.perform_later(self) if roster_stale? && claim_refresh(:roster)
    SyncAvailabilityJob.perform_later(self) if availability_stale? && claim_refresh(:availability)
  end

  # At most one write an hour, however busy the workspace.
  def touch_viewed
    update_column(:last_viewed_at, Time.current) if last_viewed_at.nil? || last_viewed_at < 1.hour.ago
  end

  def active?
    last_viewed_at.present? && last_viewed_at > ACTIVE_FOR.ago
  end

  def roster_stale?
    roster_synced_at.nil? || roster_synced_at < ROSTER_TTL.ago
  end

  def availability_stale?
    availability_synced_at.nil? || availability_synced_at < AVAILABILITY_TTL.ago
  end

  def import_person(person)
    member = members.find_or_initialize_by(slack_user_id: person.fetch(:external_id))

    if person[:deleted]
      if member.new_record?
        member.update!(Member::SCRUBBED.merge(deleted: true, is_bot: person[:is_bot] == true))
      elsif !member.deleted?
        member.depart!
      end
    else
      outside = person[:team_id].present? && person[:team_id] != slack_team_id
      attrs = person.except(:external_id, :team_id)
      member.update!(attrs.merge(name: person[:name].presence || person[:external_id], guest: person[:guest] == true || outside))
    end
    member
  end

  def sync_roster!(source: Sources::Slack.new)
    people, teams, rooms = with_source_token do |token|
      [ source.roster(token), optional_groups(source, token), optional_channels(source, token) ]
    end
    return false unless people

    transaction do
      people.each { import_person(it) }
      import_groups(teams) if teams
      import_channels(rooms) if rooms
      update!(roster_synced_at: Time.current)
    end
    true
  end

  # Replace the mirrored groups with what Slack has now.
  def import_groups(teams)
    ids_by_slack = members.where(deleted: false).pluck(:slack_user_id, :id).to_h
    keep = teams.map do |team|
      group = groups.find_or_initialize_by(slack_group_id: team[:external_id])
      group.update!(name: team[:name], handle: team[:handle], slack_updated_at: team[:updated_at])
      wanted = team[:member_ids].filter_map { ids_by_slack[it] }
      group.group_memberships.where.not(member_id: wanted).delete_all
      (wanted - group.group_memberships.pluck(:member_id)).each { group.group_memberships.create!(member_id: it) }
      group.id
    end
    groups.where.not(id: keep).destroy_all
  end

  # Replace the mirrored channel list (names and sizes) with Slack's. Who's in
  # each one is fetched separately, when it's needed.
  def import_channels(rooms)
    keep = rooms.map do |room|
      channel = channels.find_or_initialize_by(slack_channel_id: room[:external_id])
      channel.update!(name: room[:name], num_members: room[:num_members])
      channel.id
    end
    channels.where.not(id: keep).destroy_all
  end

  # Notification schedules for everyone: batched, 50 people per call.
  def sync_availability!(source: Sources::Slack.new)
    people = members.people.order(:id).limit(MAX_SCHEDULE_LOOKUPS).to_a
    return true if people.empty?

    synced = with_source_token do |token|
      now = Time.current
      schedules = source.quiet_hours(token, people.map(&:slack_user_id))
      people.each do |member|
        next unless (schedule = schedules[member.slack_user_id])
        member.update!(dnd_enabled: schedule[:enabled], dnd_starts_at: schedule[:starts_at],
                       dnd_ends_at: schedule[:ends_at], dnd_synced_at: now)
      end
      true
    end
    update!(availability_synced_at: Time.current) if synced
    !!synced
  end

  # First sign-in for a workspace: everything the first view needs.
  def prepare_first_view!
    sync_roster!
    sync_availability!
  rescue Sources::Base::Error, Faraday::Error => e
    Rails.logger.warn("Preparing workspace #{id} failed: #{e.class}: #{e.message}")
    Rails.error.report(e, handled: true, severity: :warning, context: { workspace_id: id, step: "first view" })
    SyncRosterJob.perform_later(self)
  end

  def needs_first_sync?
    roster_synced_at.nil?
  end

  private
    # True for the first caller in each window (an atomic write-if-absent in
    # the shared cache), so a burst of page loads queues a single refresh.
    def claim_refresh(kind)
      Rails.cache.write("workspace/#{id}/refresh/#{kind}", true, expires_in: FRESH_FOR, unless_exist: true)
    end

    # Without usergroups:read there are simply no group boards.
    def optional_groups(source, token)
      source.groups(token)
    rescue Sources::Base::MissingScope
      nil
    end

    # Without channels:read (people who signed in before channels) there are
    # no channel boards, and the existing list is left alone.
    def optional_channels(source, token)
      source.channels(token)
    rescue Sources::Base::MissingScope
      nil
    end
end
