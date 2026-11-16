# Everything the board view draws: one column per hour of `date` in the
# reference zone, and one row per distinct time zone on the board.
#
# All cell times are computed from UTC instants, so DST changes, half-hour
# zones, and day boundaries fall out naturally. A reference day can have
# 23, 24, or 25 columns.
class Grid
  Column = Data.define(:index, :starts_at)
  # shift: seconds the clocks moved at the start of this hour, if they did
  # (−3600 when they go back, so this hour repeats the last; +3600 when they
  # go forward, skipping one).
  # weekend: this hour falls on the zone's own weekend (see Grid.weekend_days).
  Cell = Data.define(:column, :local, :phase_start, :phase_end, :reachable_names, :people_count, :shift, :weekend) do
    def clocks_back? = shift.negative?
    def clocks_forward? = shift.positive?
    def day_start? = local.hour.zero? && local.min.zero? || (column.index.zero?)
    def midnight? = local.hour.zero?
    def reachable_fraction = people_count.zero? ? 0.0 : reachable_names.size.fdiv(people_count)
  end
  # A run of consecutive hours where the same people allow notifications.
  # Slack's schedule is the same every day, so on a weekend it's only a guess.
  Block = Data.define(:start, :length, :names, :total, :weekend) do
    def everyone? = names.size == total
  end
  Row = Data.define(:zone, :members, :cells, :reference, :offset, :now_local) do
    # The time zone's name, never a city: someone in San Francisco is on
    # Pacific Time, not in Los Angeles. Uses Slack's label for the people in
    # the row, made season-neutral ("Pacific Daylight Time" -> "Pacific Time").
    def name
      label = members.filter_map { it.tz_label.presence }.tally.max_by(&:last)&.first
      Grid.generic_zone_name(label) || abbreviation
    end

    def blocks
      cells.chunk_while { |a, b| a.reachable_names == b.reachable_names && a.weekend == b.weekend }.filter_map do |run|
        names = run.first.reachable_names
        Block.new(start: run.first.column.index, length: run.size, names:, total: run.first.people_count, weekend: run.first.weekend) if names.any?
      end
    end
    # Midday of the day shown, so a shared Oct 16 moment says BST even after
    # the UK's clocks have gone back.
    def abbreviation = Grid.zone_abbreviation(zone, cells[cells.size / 2].column.starts_at)
    # The day shown's abbreviations, "EEST → EET" on the day the clocks change.
    def day_abbreviation = cells.map { Grid.zone_abbreviation(zone, it.column.starts_at) }.uniq.join(" → ")
    # "UTC−4": the universal way to say where a zone sits, unlike "EDT" or "IST".
    # For the day shown, not today: a week before the clocks change it's still
    # UTC+3, and on the day itself "UTC+3 → UTC+2".
    def utc_offset_label = cells.map { it.local.utc_offset }.uniq.map { Grid.offset_label(it) }.join(" → ")
  end

  # Days off by zone (0 = Sunday). Saturday and Sunday unless the zone's
  # country rests on Friday and Saturday. Keys are canonical zone ids.
  FRIDAY_SATURDAY = %w[
    Africa/Cairo Africa/Khartoum Africa/Tripoli Asia/Amman Asia/Baghdad Asia/Damascus
    Asia/Gaza Asia/Hebron Asia/Jerusalem Asia/Qatar Asia/Riyadh
  ].freeze

  def self.weekend_days(zone)
    FRIDAY_SATURDAY.include?(zone.canonical_identifier) ? [ 5, 6 ] : [ 6, 0 ]
  end

  # Names listed per zone in hover titles and copied summaries; the rest are counted.
  NAMES_SHOWN = 8

  attr_reader :date, :reference_zone, :columns, :rows, :now

  # "Pacific Daylight Time" -> "Pacific Time", "India Standard Time" -> "India Time".
  def self.generic_zone_name(slack_label)
    return if slack_label.blank?
    slack_label.gsub(/\s+(?:Daylight|Summer|Standard)(?=\s+Time\b)/, "").squish
  end

  # "PDT", or "UTC−3" where the zone has no letter abbreviation.
  def self.zone_abbreviation(zone, at = Time.current)
    period = zone.period_for(at)
    abbr = period.abbreviation.to_s
    abbr.match?(/\A[A-Z]{2,5}\z/) ? abbr : offset_label(period.observed_utc_offset)
  end

  def self.offset_label(seconds)
    sign = seconds.negative? ? "−" : "+"
    hours, minutes = seconds.abs.divmod(3600)
    minutes /= 60
    "UTC#{sign}#{hours}#{":%02d" % minutes if minutes.positive?}"
  end

  def initialize(members:, reference_tz:, date: nil, now: Time.current)
    @now = now.utc
    @reference_zone = safe_zone(reference_tz) || TZInfo::Timezone.get("Etc/UTC")
    @date = date || today
    @daylight = Hash.new { |h, (tz, d)| h[[ tz, d ]] = Daylight.for(tz, d) }
    @columns = build_columns
    @rows = build_rows(members)
  end

  def today = reference_zone.to_local(now).to_date

  # Each row's days off, for the page to say when a picked time is someone's weekend.
  def weekend_days = rows.to_h { [ it.zone.identifier, Grid.weekend_days(it.zone) ] }

  def any_weekend? = rows.any? { |row| row.cells.any?(&:weekend) }

  def reference_name
    rows.find(&:reference)&.name || Grid.zone_abbreviation(reference_zone, starts_at)
  end
  def today? = date == today
  def starts_at = columns.first.starts_at
  def ends_at = columns.last.starts_at + 1.hour

  # Where "now" falls across the strip, 0.0–1.0, or nil if not on this day.
  def now_fraction
    return unless now >= starts_at && now < ends_at
    (now - starts_at) / (ends_at - starts_at)
  end

  def current_column_index
    return unless (fraction = now_fraction)
    columns.index { |col| now >= col.starts_at && now < col.starts_at + 1.hour } || (fraction * columns.size).floor
  end

  # Each zone's local time at a column, and who's there. `day` is set only
  # where the date differs from the reference zone's; `weekday` always is.
  # names: false on anonymous views (shared links), which never show who's where.
  def zone_times(column, names: true)
    reference_day = reference_zone.to_local(column.starts_at).to_date
    rows.map do |row|
      local = row.zone.to_local(column.starts_at)
      weekday = I18n.l(local.to_date, format: "%a")
      { zone: row.name, tz: row.zone.identifier, t12: I18n.l(local, format: :clock_12), t24: I18n.l(local, format: :clock_24),
        weekday:, day: (weekday unless local.to_date == reference_day),
        names: names ? row.members.first(NAMES_SHOWN).map(&:label) : [], count: names ? row.members.size : 0 }
    end
  end

  # "Thu 10:00 Los Angeles · 13:00 New York · Fri 02:00 Tokyo"
  def summary(column, h12: false)
    reference_day = reference_zone.to_local(column.starts_at).to_date
    rows.map do |row|
      local = row.zone.to_local(column.starts_at)
      time = I18n.l(local, format: h12 ? :clock_12 : :clock_24)
      day = local.to_date == reference_day && row != rows.first ? nil : I18n.l(local.to_date, format: "%a")
      [ day, time, row.name ].compact.join(" ")
    end.join(" · ")
  end

  private
    def safe_zone(tz)
      TZInfo::Timezone.get(tz) if tz.present?
    rescue TZInfo::InvalidTimezoneIdentifier
      nil
    end

    def build_columns
      first = local_midnight_utc(date)
      last = local_midnight_utc(date + 1)
      times = []
      t = first
      while t < last
        times << t
        t += 1.hour
      end
      times.each_with_index.map { |time, i| Column.new(index: i, starts_at: time) }
    end

    # Midnight can be skipped or repeated by DST in a few zones; take the
    # first instant that is on `day`.
    def local_midnight_utc(day)
      local = Time.utc(day.year, day.month, day.day)
      reference_zone.local_to_utc(local) { |periods| periods.first }
    rescue TZInfo::PeriodNotFound
      reference_zone.local_to_utc(local + 1.hour) { |periods| periods.first }
    end

    def build_rows(members)
      groups = members.filter_map { |m| [ m.zone.canonical_zone, m ] if m.zone }.group_by(&:first)
      reference_canonical = reference_zone.canonical_zone

      rows = groups.map do |zone, pairs|
        people = pairs.map(&:last)
        Row.new(
          zone:,
          members: people,
          cells: build_cells(zone, people),
          reference: zone == reference_canonical,
          offset: zone.period_for(starts_at).observed_utc_offset,
          now_local: zone.to_local(now)
        )
      end
      rows.sort_by { |row| [ row.offset, row.name ] }
    end

    def build_cells(zone, people)
      windows = people.filter_map { |p| [ p.label, p.reachable_minutes ] if p.reachable_minutes }
      days_off = Grid.weekend_days(zone)
      previous_offset = nil
      columns.map do |column|
        local = zone.to_local(column.starts_at)
        shift = previous_offset ? local.utc_offset - previous_offset : 0
        previous_offset = local.utc_offset
        minute = local.hour * 60 + local.min
        Cell.new(
          column:,
          local:,
          phase_start: phase(zone, column.starts_at),
          phase_end: phase(zone, column.starts_at + 59.minutes),
          reachable_names: windows.select { |_, window| within?(minute, window) }.map(&:first),
          people_count: windows.size,
          shift:,
          weekend: days_off.include?(local.wday)
        )
      end
    end

    # Far north in summer, last evening's twilight runs past midnight (Helsinki's
    # ends around 00:40 in June), so a "night" just after midnight checks the
    # previous day's dusk too.
    def phase(zone, time)
      date = zone.to_local(time).to_date
      today = @daylight[[ zone.identifier, date ]].phase_at(time)
      return today unless today == :night

      @daylight[[ zone.identifier, date - 1 ]].phase_at(time)
    end

    def within?(minute, (from, to))
      from < to ? minute >= from && minute < to : minute >= from || minute < to
    end
end
