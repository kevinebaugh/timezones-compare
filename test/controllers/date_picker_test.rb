require "test_helper"

class DatePickerTest < ActionDispatch::IntegrationTest
  setup do
    workspaces(:acme).update!(roster_synced_at: Time.current, availability_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
  end

  test "one pill holds the day arrows and the date; Today shows only on other days" do
    travel_to Time.utc(2026, 10, 15, 18) do
      get board_path("everyone")
      assert_select "nav.day-nav a.day-step", 2
      assert_select "nav.day-nav details.date-pop", 1
      assert_select "a.today-link", 0

      get board_path("everyone", date: "2026-10-30")
      assert_select "a.today-link[href='/boards/everyone']", "Today"
    end
  end

  test "the date opens our own calendar, and days keep the chosen time zone" do
    get board_path("everyone", date: "2026-10-16", tz: "Europe/London")
    assert_select "details.date-pop[data-calendar-selected-value='2026-10-16']" do |pop|
      assert_equal "/boards/everyone?date=2000-01-01&tz=Europe%2FLondon", pop.first["data-calendar-url-value"]
      assert_select "summary.date-pick-button", /Friday, October 16/
      assert_select ".cal[role='dialog']"
    end
    assert_select "input[type='date']", 0
  end

  test "each zone's own weekend is marked on its row, not the whole board" do
    get board_path("everyone", date: "2026-10-16", tz: "America/Los_Angeles") # Friday in Pacific Time
    pacific, *, kolkata = css_select(".tz-row")
    assert_empty pacific.css(".tz-cell.is-off"), "Friday all day for Kev"
    assert kolkata.css(".tz-cell.is-off").any?, "Friday afternoon Pacific is already Saturday in India"
    assert_select ".legend .swatch-weekend"
    assert_select ".weekend-note", 0

    get board_path("everyone", date: "2026-10-14", tz: "America/Los_Angeles") # a Wednesday everywhere
    assert_select ".tz-cell.is-off", 0
    assert_select ".legend .swatch-weekend", 0
  end

  test "dates in another year show the year" do
    get board_path("everyone", date: "2027-03-02")
    assert_select "summary.date-pick-button", /Tuesday, March 2, 2027/
  end

  test "a shared moment has no date controls" do
    get moment_path(Time.utc(2026, 10, 17, 17).to_i, z: "America/Los_Angeles")
    assert_select ".date-pop", 0
    assert_select ".weekend-note", 0
  end
end
