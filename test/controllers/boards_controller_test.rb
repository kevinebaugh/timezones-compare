require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    workspaces(:acme).update!(roster_synced_at: Time.current, availability_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
  end

  test "Everyone shows every colleague, one row per zone, without bots or guests" do
    members(:sam).update!(guest: true)
    get board_path("everyone", date: "2026-10-16")
    assert_response :success
    assert_select ".tz-row .city", 3 # Pacific, British, and India Time
    assert_select ".tz-row.is-reference .city", "Pacific Time"
    assert_no_match(/Los Angeles|London|Kolkata/, css_select(".tz-row").text, "time zones, never cities")
    assert_no_match "Deploy Bot", response.body
    assert_no_match "Sam Lee", response.body
  end

  test "people without Slack working hours get a gentle note" do
    get board_path("everyone")
    assert_select "li", text: /Noor.*working hours \d/m
    assert_select "li", text: /Kev \(you\).*no working hours set yet/m
  end

  test "each zone shows its UTC offset, with the abbreviation on hover" do
    travel_to Time.utc(2026, 10, 16, 17) do # current offsets: Pacific is UTC−7 until November
      get board_path("everyone", date: "2026-10-16")
      assert_select ".tz-row.is-reference .meta[title='PDT · UTC−7'] .abbr", "· UTC−7"
      assert_select ".tz-row .meta .abbr", "· UTC+5:30"
    end
  end

  test "the hour the clocks change is marked, with the details on hover" do
    get board_path("everyone", date: "2026-11-01", tz: "America/Los_Angeles")
    cell = css_select(".tz-row.is-reference .tz-cell.is-shift-back").sole
    assert_includes cell["title"], I18n.t("grid.clocks_back", from: "PDT", to: "PST", time: "01:00")
    assert_select cell, ".shift-mark", "↺"
    get board_path("everyone", date: "2026-10-16")
    assert_select ".tz-cell.is-shift", 0
  end

  test "another day shows that day's offsets and no live clock" do
    travel_to Time.utc(2026, 10, 16, 17) do
      get board_path("everyone", date: "2026-11-02") # Pacific is back on standard time
      assert_select ".tz-row.is-reference .meta[title='PST · UTC−8'] .abbr", "UTC−8"
      assert_select ".tz-row [data-grid-target='clock']", 0

      get board_path("everyone", date: "2026-11-01") # the day the clocks change
      assert_select ".tz-row.is-reference .meta .abbr", "UTC−7 → UTC−8"
    end
  end

  test "tabs list the whole workspace and only the groups I'm in" do
    get board_path("everyone")
    assert_select ".board-tabs > a", text: "Acme"
    assert_select ".board-tabs > a", text: /Mobile Team/
    assert_select ".board-tabs > a", text: /Leadership/, count: 0
  end

  test "a group board shows its members, even guests" do
    members(:noor).update!(guest: true)
    get board_path("mobile-team", date: "2026-10-16")
    assert_response :success
    assert_select ".tz-row .city", 2 # Kev on Pacific Time, Noor on British Time
    assert_match "Mirrors the @mobile-team group", response.body
  end

  test "groups I'm not in are listed under More groups, not as tabs" do
    get board_path("everyone")
    assert_select ".board-tabs > a", text: /Leadership/, count: 0
    assert_select ".groups-list a.group-item:not([data-section='your_tabs'])", 1
    assert_select ".groups-list a.group-item[href^='/boards/leadership']", /Leadership.*@leadership\s*1/m
    assert_select ".groups-list a.group-item[href^='/boards/leadership'] .group-count[title='1 person']", "1"
    assert_select ".groups-list a:not([data-section='your_tabs'])", text: /Mobile Team/, count: 0
  end

  test "any group in the workspace opens, as an extra tab, without changing my tab order" do
    get board_path("leadership")
    assert_response :success
    assert_select ".board-tabs > a.is-visiting[aria-current='page']", /Leadership/
    assert_select ".tz-row", 1
    assert_select "section", /#{Regexp.escape(I18n.t("boards.not_a_member"))}/
    assert_not BoardVisit.exists?(board_key: "leadership"), "visiting someone else's group doesn't rank it"

    get board_path("mobile-team")
    assert_select ".board-tabs > a.is-visiting", 0
    assert_no_match I18n.t("boards.not_a_member"), response.body
  end

  test "groups from other workspaces, and empty groups, stay out of reach" do
    other = Workspace.create!(slack_team_id: "TOTHER", name: "Other")
    other.groups.create!(slack_group_id: "SX", name: "Secret", handle: "secret")
    get board_path("secret")
    assert_response :not_found

    workspaces(:acme).groups.create!(slack_group_id: "SEMPTY", name: "Empty", handle: "empty")
    get board_path("everyone")
    assert_select ".groups-list a", text: /Empty/, count: 0
  end

  test "no More groups menu when I'm in every group" do
    group_memberships(:priya_leadership).update!(member: members(:kev))
    users(:kev).update!(token_scopes: Sources::Slack::USER_SCOPES.join(","))
    get board_path("everyone")
    assert_select ".groups-heading:not([data-section='your_tabs']):not([data-section='people'])", 0
  end

  test "a DST change day has 25 columns" do
    get board_path("everyone", date: "2026-11-01")
    assert_select ".tz-row:first-child .tz-cell", 25
  end

  test "clicking a time zone makes it the reference, and garbage params fall back safely" do
    get board_path("everyone", date: "2026-10-16")
    assert_select "a.zone-link[href*='tz=Europe%2FLondon']", "British Time"
    assert_select "select#tz", 0

    get board_path("everyone", tz: "Europe/London", date: "2026-10-16")
    assert_select ".tz-row.is-reference .city", "British Time"
    get board_path("everyone", tz: "Mars/Olympus", date: "nope")
    assert_response :success
  end

  test "every page, including error pages, carries the footer" do
    get board_path("everyone")
    assert_select "footer a[href='https://kevinebaugh.com']", "Kevin Ebaugh"
    assert_select "footer", /Built by Kevin Ebaugh\./
    assert_select "footer", text: /Tested at/, count: 0
    assert_select "footer a[href='/privacy']", "Privacy"
    assert_select "footer a[href='/support']", "Support"

    delete sign_out_all_path
    get root_path
    assert_select "footer a[href='https://kevinebaugh.com']", "Kevin Ebaugh"

    Dir[Rails.root.join("public/*.html")].each do |page|
      html = File.read(page)
      assert_includes html, %(href="https://kevinebaugh.com"), page
      assert_includes html, %(href="/privacy"), page
      assert_includes html, %(href="/support"), page
    end
  end

  test "no 'Synced from Slack' timestamp; boards just stay fresh" do
    get board_path("everyone")
    assert_no_match(/Synced from Slack/, response.body)
  end

  test "home goes straight to Everyone" do
    get root_path
    assert_redirected_to board_path("everyone")
  end

  test "signed-out visitors are sent home, without a nag" do
    delete sign_out_path
    get board_path("everyone")
    assert_redirected_to root_path
    assert_nil flash[:alert]
  end

  test "calendar guests are the board's people, minus me" do
    members(:kev).update!(email: "kev@acme.test")
    members(:noor).update!(email: "noor@acme.test")
    get board_path("mobile-team")
    assert_select "[data-grid-guests-value='[\"noor@acme.test\"]']"
  end

  test "opening a group board counts toward its tab order" do
    get board_path("mobile-team")
    assert_operator BoardVisit.find_by!(user: users(:kev), board_key: "mobile-team").score, :>=, 1
  end
end
