require "test_helper"

class GridTest < ActiveSupport::TestCase
  setup do
    @members = [ members(:kev), members(:sam), members(:noor), members(:priya) ]
    @grid = Grid.new(members: @members, reference_tz: "America/Los_Angeles", date: Date.new(2026, 10, 16), now: Time.utc(2026, 10, 16, 17, 30))
  end

  test "rows are named by time zone, never a city, and sorted by offset" do
    assert_equal [ "Pacific Time", "British Time", "India Time" ], @grid.rows.map(&:name)
    assert_equal 2, @grid.rows.first.members.size
  end

  test "half-hour zones keep their minutes" do
    kolkata = @grid.rows.last
    assert_equal [ 12, 30 ], [ kolkata.cells.first.local.hour, kolkata.cells.first.local.min ]
  end

  test "now line position" do
    assert_in_delta 10.5 / 24, @grid.now_fraction, 0.001
    assert_equal 10, @grid.current_column_index
  end

  test "zone_times marks the day only where it differs from the reference" do
    times = @grid.zone_times(@grid.columns[13])
    assert_equal({ zone: "Pacific Time", tz: "America/Los_Angeles", t12: "1:00 PM", t24: "13:00", weekday: "Fri", day: nil, names: [ "Kev", "Sam Lee" ], count: 2 }, times.first)
    assert_equal({ zone: "India Time", tz: "Asia/Kolkata", t12: "1:30 AM", t24: "01:30", weekday: "Sat", day: "Sat", names: [ "Priya Rao" ], count: 1 }, times.last)
  end

  test "summary names each zone and marks day changes" do
    assert_equal "Fri 10:00 Pacific Time · 18:00 British Time · 22:30 India Time", @grid.summary(@grid.columns[10])
    assert_equal "Fri 1:00 PM Pacific Time · 9:00 PM British Time · Sat 1:30 AM India Time", @grid.summary(@grid.columns[13], h12: true)
  end

  test "zone names drop the season, and fall back to the abbreviation" do
    assert_equal "Pacific Time", Grid.generic_zone_name("Pacific Daylight Time")
    assert_equal "Central European Time", Grid.generic_zone_name("Central European Summer Time")
    assert_equal "Australian Eastern Time", Grid.generic_zone_name("Australian Eastern Daylight Time")
    assert_equal "Greenwich Mean Time", Grid.generic_zone_name("Greenwich Mean Time")
    assert_nil Grid.generic_zone_name("")
    sao_paulo = Member.new(name: "Fen", tz: "America/Sao_Paulo")
    assert_equal "UTC−3", sao_paulo.zone_name
    assert_equal "JST", Member.new(name: "Kai", tz: "Asia/Tokyo").zone_name
  end

  test "reachable window from Slack notification schedule" do
    london = @grid.rows.second
    reachable_hours = london.cells.select { it.reachable_names.any? }.map { it.local.hour }
    assert_equal (9..22).to_a, reachable_hours
  end

  test "Helsinki midsummer twilight runs past midnight instead of turning to night" do
    helsinki = Member.new(slack_user_id: "UFI", name: "Aino", tz: "Europe/Helsinki")
    row = Grid.new(members: [ helsinki ], reference_tz: "Europe/Helsinki", date: Date.new(2026, 6, 21)).rows.first
    phases = row.cells.map(&:phase_start)
    assert_equal :twilight, phases[0], "00:00, before the previous dusk at ~00:41"
    assert_equal :night, phases[1], "01:00, the short real night"
    assert_equal :day, phases[12]
    assert_equal :twilight, phases[23], "23:00, after sunset at ~22:49"
  end

  test "Helsinki midwinter has a short day" do
    helsinki = Member.new(slack_user_id: "UFI", name: "Aino", tz: "Europe/Helsinki")
    row = Grid.new(members: [ helsinki ], reference_tz: "Europe/Helsinki", date: Date.new(2026, 12, 21)).rows.first
    assert_equal (10..14).to_a, row.cells.each_index.select { row.cells[it].phase_start == :day && row.cells[it].phase_end == :day }
  end

  test "notification blocks group consecutive hours with the same people" do
    london = @grid.rows.second
    assert_equal 1, london.blocks.size
    block = london.blocks.first
    assert block.everyone?
    assert_equal [ "Noor Aziz" ], block.names
    assert_equal 14, block.length # notifications allowed 09:00–23:00 BST
  end

  test "zones without a notification schedule have no blocks" do
    assert_empty @grid.rows.first.blocks # Kev and Sam have no schedule
  end

  test "spring-forward day has 23 columns" do
    assert_equal 23, Grid.new(members: [], reference_tz: "America/Los_Angeles", date: Date.new(2026, 3, 8)).columns.size
  end

  test "big rows send a few names and a count, not everyone in every hour" do
    many = Array.new(12) { |i| Member.new(name: "Person #{i}", tz: "America/Los_Angeles", tz_label: "Pacific Daylight Time") }
    grid = Grid.new(members: many, reference_tz: "America/Los_Angeles", date: Date.new(2026, 10, 16))
    zone = grid.zone_times(grid.columns.first).first
    assert_equal Grid::NAMES_SHOWN, zone[:names].size
    assert_equal 12, zone[:count]
  end

  test "a row's UTC offset is the day shown's, and shows the change on the day clocks change" do
    athens = [ Member.new(name: "Art", tz: "Europe/Athens", tz_label: "Eastern European Summer Time") ]
    now = Time.utc(2026, 10, 26, 13) # the Monday after summer time ends (Sun Oct 25, 04:00 local)
    day = ->(date) { Grid.new(members: athens, reference_tz: "Europe/Athens", date:, now:).rows.first }

    assert_equal "UTC+3", day.(Date.new(2026, 10, 19)).utc_offset_label, "a week back, still summer time"
    assert_equal "UTC+3 → UTC+2", day.(Date.new(2026, 10, 25)).utc_offset_label
    assert_equal "EEST → EET", day.(Date.new(2026, 10, 25)).day_abbreviation
    assert_equal "UTC+2", day.(Date.new(2026, 10, 26)).utc_offset_label
    assert_equal "Eastern European Time", day.(Date.new(2026, 10, 19)).name, "the name doesn't move with the day"
  end

  test "cells mark where the clocks change" do
    london = [ Member.new(name: "Erich", tz: "Europe/London", tz_label: "British Summer Time") ]
    back = Grid.new(members: london, reference_tz: "Europe/London", date: Date.new(2026, 10, 25)).rows.first.cells
    assert_equal [ 0, -3600 ], back.first(3).map(&:shift).values_at(0, 2), "01:00 BST, 01:00 GMT"
    assert back[2].clocks_back?
    assert_equal [ 1, 1 ], back.values_at(1, 2).map { it.local.hour }
    assert_equal 1, back.count { !it.shift.zero? }

    forward = Grid.new(members: london, reference_tz: "Europe/London", date: Date.new(2027, 3, 28)).rows.first.cells
    jump = forward.find(&:clocks_forward?)
    assert_equal [ 2, 3600 ], [ jump.local.hour, jump.shift ], "00:00 GMT, then 02:00 BST: 01:00 is skipped"
  end

  test "weekends follow each zone's own days off" do
    assert_equal [ 6, 0 ], Grid.weekend_days(TZInfo::Timezone.get("Australia/Sydney"))
    assert_equal [ 5, 6 ], Grid.weekend_days(TZInfo::Timezone.get("Asia/Jerusalem"))
    assert_equal [ 5, 6 ], Grid.weekend_days(TZInfo::Timezone.get("Asia/Kuwait")), "aliases count"

    people = [ Member.new(name: "Kevin", tz: "America/New_York", tz_label: "Eastern Standard Time", dnd_enabled: true,
                          dnd_starts_at: Time.utc(2026, 11, 13, 23), dnd_ends_at: Time.utc(2026, 11, 14, 13)),
               Member.new(name: "Michael", tz: "Australia/Sydney", tz_label: "Australian Eastern Daylight Time", dnd_enabled: true,
                          dnd_starts_at: Time.utc(2026, 11, 13, 13), dnd_ends_at: Time.utc(2026, 11, 13, 20)) ]
    friday = Grid.new(members: people, reference_tz: "America/New_York", date: Date.new(2026, 11, 13))
    eastern, sydney = friday.rows
    assert eastern.cells.none?(&:weekend)
    assert sydney.cells.select { it.local.saturday? }.all?(&:weekend), "Friday 4pm Eastern is Saturday 8am in Sydney"
    assert sydney.blocks.any?(&:weekend), "his working hours on Saturday are faded"
    assert friday.any_weekend?
  end
end
