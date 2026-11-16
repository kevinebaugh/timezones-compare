# The live sample board on the signed-out home page: a made-up team drawn by
# the real Grid for today, with the visitor's own zone as the reference row.
# Nothing here touches the database.
#
# The team is shaped like a real one: weighted toward US time zones, varied
# working hours (and one person with none set), names from many backgrounds
# spread across every region rather than matched to them, and illustrated
# avatars with no skin tone (Notionists by Zoish, CC0; see public/preview-avatars).
module HomePreview
  DEFAULT_TZ = "America/New_York"

  # [time zone, Slack-style label, [name, working hours from, to]...]; nil hours = none set.
  TEAM = [
    [ "America/Los_Angeles", "Pacific Time",
      [ "Maya Okafor", 9, 17 ], [ "Daniel Kim", 8, 16 ], [ "Priya Natarajan", 10, 18 ],
      [ "Luis Hernández", 9, 17.5 ], [ "Sam Whitfield", 7, 15 ], [ "Aiyana Brooks", 12, 20 ] ],
    [ "America/Denver", "Mountain Time", [ "Jordan Ellis", 8, 16 ], [ "Fatima Haddad", 9, 17 ] ],
    [ "America/Chicago", "Central Time", [ "Noah Lindqvist", nil, nil ] ],
    [ "America/New_York", "Eastern Time",
      [ "Grace Mensah", 9, 17 ], [ "Wei Zhang", 10, 18 ], [ "Hannah Levi", 8, 16 ], [ "Marcus Johnson", 9.5, 17.5 ] ],
    [ "America/Sao_Paulo", "Brasilia Time", [ "Camila Duarte", 9, 18 ], [ "Kenji Watanabe", 8, 17 ] ],
    [ "Europe/London", "British Time", [ "Amara Nwosu", 9, 17 ], [ "Tom Gallagher", 10, 18.5 ] ],
    [ "Europe/Berlin", "Central European Time", [ "Lena Fischer", 9, 17 ], [ "Youssef Benali", 8, 16 ] ],
    [ "Europe/Kyiv", "Eastern European Time", [ "Olena Kovalenko", 10, 19 ] ],
    [ "Asia/Kolkata", "India Time", [ "Arjun Mehta", 11, 20 ], [ "Sara Thomas", 9.5, 18 ] ],
    [ "Asia/Singapore", "Singapore Time", [ "Nur Aisyah", 9, 18 ] ],
    [ "Australia/Sydney", "Australian Eastern Time", [ "Mia Tran", 8, 16 ] ]
  ].freeze

  def self.people = TEAM.flat_map { |_, _, *people| people.map(&:first) }
  def self.avatar_path(name) = "/preview-avatars/#{name.parameterize}.svg"

  def self.grid(tz, date: nil, now: Time.current)
    tz = DEFAULT_TZ unless TZInfo::Timezone.all_identifiers.include?(tz.to_s)
    members = TEAM.flat_map do |zone_id, label, *people|
      people.map { |name, from, to| member(name, zone_id, label, from, to, now) }
    end
    unless members.any? { it.zone.canonical_zone == TZInfo::Timezone.get(tz).canonical_zone }
      members << member(I18n.t("home.you"), tz, nil, 9, 17, now, avatar: false)
    end
    Grid.new(members:, reference_tz: tz, date:, now:)
  end

  # Slack stores the quiet stretch, so working 9 to 5 is quiet from 5 to 9.
  def self.member(name, tz, label, from, to, now, avatar: true)
    zone = TZInfo::Timezone.get(tz)
    day = zone.to_local(now).to_date
    at = ->(hours) { zone.local_to_utc(Time.utc(day.year, day.month, day.day) + (hours * 3600).round) }
    Member.new(name:, slack_user_id: "PREVIEW-#{name.parameterize}", tz:, tz_label: label,
               avatar_url: (avatar_path(name) if avatar),
               dnd_enabled: from.present?, dnd_starts_at: (at.(to) if to), dnd_ends_at: (at.(from) if from))
  end
end
