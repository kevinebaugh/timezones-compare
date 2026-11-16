# Demo workspace used by the FAKE_SLACK=1 sign-in in development.
# Safe to run repeatedly. Never seeds production.

return if Rails.env.production?

# What Slack reports as each person's tz_label (in October).
slack_labels = {
  "America/Los_Angeles" => "Pacific Daylight Time", "America/Denver" => "Mountain Daylight Time",
  "America/Mexico_City" => "Central Standard Time", "America/New_York" => "Eastern Daylight Time",
  "America/Sao_Paulo" => "Brasilia Standard Time", "Europe/London" => "British Summer Time",
  "Europe/Berlin" => "Central European Summer Time", "Africa/Lagos" => "West Africa Standard Time",
  "Asia/Kolkata" => "India Standard Time", "Asia/Tokyo" => "Japan Standard Time",
  "Australia/Sydney" => "Australian Eastern Daylight Time"
}

demo_people = [
  # name,             tz,                       reachable local hours (nil = no schedule)
  [ "Ada Park",        "America/Los_Angeles",   [ 9, 18 ] ],
  [ "Bea Quinn",       "America/Los_Angeles",   [ 13, 2 ] ],   # night owl
  [ "Cy Okafor",       "America/Denver",        [ 7, 16 ] ],
  [ "Dee Ramírez",     "America/Mexico_City",   nil ],
  [ "Eli Novak",       "America/New_York",      [ 8, 17 ] ],
  [ "Fen Liu",         "America/Sao_Paulo",     [ 10, 19 ] ],
  [ "Gus Byrne",       "Europe/London",         [ 9, 17 ] ],
  [ "Hana Weiss",      "Europe/Berlin",         [ 11, 23 ] ],
  [ "Ines Haddad",     "Africa/Lagos",          [ 8, 16 ] ],
  [ "Jai Mehta",       "Asia/Kolkata",          [ 12, 21 ] ],
  [ "Kai Tanaka",      "Asia/Tokyo",            [ 10, 19 ] ],
  [ "Lou Harper",      "Australia/Sydney",      [ 20, 4 ] ]    # night owl
]

workspace = Workspace.find_or_create_by!(slack_team_id: "TDEMO") do |w|
  w.name = "Demo Co"
  w.domain = "demo-co"
end

demo_people.each_with_index do |(name, tz, hours), i|
  member = workspace.members.find_or_initialize_by(slack_user_id: format("UDEMO%02d", i))
  zone = TZInfo::Timezone.get(tz)
  member.assign_attributes(
    name: name.downcase.split.first,
    display_name: name,
    tz: tz,
    tz_label: slack_labels.fetch(tz),
    tz_offset: zone.current_period.observed_utc_offset,
    dnd_synced_at: Time.current
  )

  if hours
    reachable_from, reachable_to = hours
    today = zone.to_local(Time.current).to_date
    # Quiet hours run from the end of the reachable window to its start.
    quiet_start = zone.local_to_utc(Time.utc(today.year, today.month, today.day, reachable_to % 24))
    quiet_end = zone.local_to_utc(Time.utc(today.year, today.month, today.day, reachable_from))
    quiet_end += 1.day if quiet_end <= quiet_start
    member.assign_attributes(dnd_enabled: true, dnd_starts_at: quiet_start, dnd_ends_at: quiet_end)
  else
    member.assign_attributes(dnd_enabled: false, dnd_starts_at: nil, dnd_ends_at: nil)
  end
  member.save!
end

demo_groups = {
  "Platform" => [ 0, 2, 4, 7, 9 ],
  "Design" => [ 0, 1, 5, 6 ],
  "Leadership" => [ 0, 4, 6, 10, 11 ]
}
by_index = workspace.members.where("slack_user_id LIKE 'UDEMO%'").index_by { it.slack_user_id.delete_prefix("UDEMO").to_i }
workspace.import_groups(demo_groups.map do |name, indexes|
  { external_id: "SDEMO#{name.upcase}", name:, handle: name.downcase,
    member_ids: indexes.map { by_index[it].slack_user_id } }
end)

# Public channels: names, sizes and members, as a channels:read sync would leave them.
demo_channels = {
  "general" => (0..11).to_a,
  "launches" => [ 0, 1, 3, 5, 8, 10 ],
  "random" => [ 1, 2, 3, 6, 9 ],
  "design-crit" => [ 1, 5, 6 ]
}
workspace.import_channels(demo_channels.map { |name, indexes| { external_id: "CDEMO#{name.upcase}", name:, num_members: indexes.size } })
demo_channels.each do |name, indexes|
  workspace.channels.find_by!(name:).import_members!(indexes.map { by_index[it].slack_user_id })
end

workspace.update!(roster_synced_at: Time.current, availability_synced_at: Time.current)
puts "Seeded #{workspace.members.count} demo members in #{workspace.name}."
