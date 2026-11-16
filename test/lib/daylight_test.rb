require "test_helper"

class DaylightTest < ActiveSupport::TestCase
  def assert_close(expected, actual, minutes: 4)
    assert actual, "expected a time near #{expected}"
    assert_in_delta expected.to_i, actual.to_i, minutes * 60, "expected #{expected}, got #{actual}"
  end

  test "London midsummer" do
    day = Daylight.for("Europe/London", Date.new(2026, 6, 21))
    assert_close Time.utc(2026, 6, 21, 3, 43), day.sunrise
    assert_close Time.utc(2026, 6, 21, 20, 21), day.sunset
  end

  test "Los Angeles winter solstice, sunset falls on the next UTC day" do
    day = Daylight.for("America/Los_Angeles", Date.new(2026, 12, 21))
    assert_close Time.utc(2026, 12, 21, 14, 55), day.sunrise
    assert_close Time.utc(2026, 12, 22, 0, 48), day.sunset
    assert day.dawn < day.sunrise
  end

  test "Sydney in December" do
    day = Daylight.for("Australia/Sydney", Date.new(2026, 12, 21))
    assert_close Time.utc(2026, 12, 20, 18, 41), day.sunrise # 05:41 AEDT
    assert_close Time.utc(2026, 12, 21, 9, 5), day.sunset    # 20:05 AEDT
  end

  SVALBARD = [ 78.22, 15.65 ].freeze
  TRONDHEIM = [ 63.43, 10.39 ].freeze

  test "polar night in Svalbard" do
    day = Daylight.calculate(*SVALBARD, Date.new(2026, 12, 21))
    assert_equal :night, day.polar
    assert_equal :night, day.phase_at(Time.utc(2026, 12, 21, 12))
  end

  test "midnight sun in Svalbard" do
    day = Daylight.calculate(*SVALBARD, Date.new(2026, 6, 21))
    assert_equal :day, day.phase_at(Time.utc(2026, 6, 21, 0))
  end

  test "white nights in Trondheim stay in twilight" do
    day = Daylight.calculate(*TRONDHEIM, Date.new(2026, 6, 21))
    assert_equal :day, day.civil_polar
    assert_equal :twilight, day.phase_at(Time.utc(2026, 6, 21, 23, 15)) # 01:15 local
  end

  test "phases across a day" do
    day = Daylight.for("Europe/London", Date.new(2026, 3, 20))
    assert_equal :night, day.phase_at(Time.utc(2026, 3, 20, 3))
    assert_equal :twilight, day.phase_at(day.sunrise - 10.minutes)
    assert_equal :day, day.phase_at(Time.utc(2026, 3, 20, 12))
    assert_equal :twilight, day.phase_at(day.sunset + 10.minutes)
    assert_equal :night, day.phase_at(Time.utc(2026, 3, 20, 23))
  end

  test "links and unknown zones still work" do
    assert_equal Daylight.coordinates("America/Los_Angeles"), Daylight.coordinates("US/Pacific")
    assert_equal [ 0.0, 0.0 ], Daylight.coordinates("Etc/UTC")
    assert_equal [ 0.0, 0.0 ], Daylight.coordinates("Not/AZone")
  end
end
