require "test_helper"

class SharedLinkDriftTest < ActionDispatch::IntegrationTest
  AT = Time.utc(2026, 10, 16, 17).to_i
  MADE = Time.utc(2026, 10, 12, 15).to_i
  NOW_ZONES = "America/Los_Angeles,Europe/London,Asia/Kolkata" # Acme's everyone board

  setup do
    workspaces(:acme).update!(roster_synced_at: Time.current, availability_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
  end

  test "a teammate opening a link lands on the board with the zones as shared" do
    get moment_path(AT, z: NOW_ZONES, tz: "America/Los_Angeles", b: "everyone", g: MADE)
    assert_redirected_to board_path("everyone", date: "2026-10-16", tz: "America/Los_Angeles", pin: AT, shared_z: NOW_ZONES, shared_at: MADE)
  end

  test "links made before this, without a creation time, redirect as before" do
    get moment_path(AT, z: NOW_ZONES, tz: "America/Los_Angeles", b: "everyone")
    assert_redirected_to board_path("everyone", date: "2026-10-16", tz: "America/Los_Angeles", pin: AT)
  end

  test "no note when the board's zones still match the link" do
    get board_path("everyone", date: "2026-10-16", pin: AT, shared_z: NOW_ZONES, shared_at: MADE)
    assert_response :success
    assert_select ".shared-drift", 0
  end

  test "zones gained and lost since the link was made are listed, with a Now / As shared switch" do
    get board_path("everyone", date: "2026-10-16", pin: AT, shared_z: "America/Los_Angeles,Europe/London,America/New_York", shared_at: MADE)
    assert_select ".shared-drift", /#{Regexp.escape(I18n.t("boards.shared_note", date: "Mon, Oct 12"))}/
    assert_select ".shared-drift .drift-added [data-zone-name-tz-value='Asia/Kolkata']"
    assert_select ".shared-drift .drift-gone [data-zone-name-tz-value='America/New_York']"
    assert_select ".shared-drift .segmented a[aria-current='page']", I18n.t("boards.shared_now")
    assert_select ".shared-drift .segmented a[href*='view=shared']", I18n.t("boards.as_shared")
    assert_select ".tz-row .avatar", minimum: 1
  end

  test "each zone name appears once, and long lists are cut short" do
    members(:noor).update!(tz: "Europe/Lisbon", tz_label: "Greenwich Mean Time") # a second, separate zone named like London
    get board_path("everyone", shared_z: "America/Los_Angeles,Asia/Tokyo,Asia/Seoul,Asia/Dubai,Asia/Dhaka,Asia/Bangkok,Europe/Paris", shared_at: MADE)
    assert_select ".drift-gone", 4
    assert_select ".shared-drift .text-faint", I18n.t("grid.more", count: 2)
    assert_select ".drift-added [data-zone-name-tz-value='Asia/Kolkata']", text: "India Time" # the board's own name
  end

  test "a zone swapped for a same-named one isn't listed" do
    members(:priya).update!(tz: "Europe/Belgrade", tz_label: "Central European Summer Time") # on the board now
    Member.create!(workspace: workspaces(:acme), slack_user_id: "UGUEST", name: "Guest", guest: true,
                   tz: "Europe/Brussels", tz_label: "Central European Summer Time") # names Brussels, but isn't on the board
    get board_path("everyone", shared_z: "America/Los_Angeles,Europe/London,Europe/Brussels,Asia/Tokyo", shared_at: MADE)
    assert_select ".drift-gone", 1 # Japan only
    assert_select ".drift-added", 0

    get board_path("everyone", shared_z: "America/Los_Angeles,Europe/London,Europe/Brussels", shared_at: MADE)
    assert_select ".shared-drift", 0, "nothing left to say"
    assert_no_match(/Central European/, css_select(".shared-drift p").text)
  end

  test "As shared shows the link's zones without names, still pinned" do
    get board_path("everyone", date: "2026-10-16", pin: AT, shared_z: "America/Los_Angeles,Europe/London,America/New_York", shared_at: MADE, view: "shared")
    assert_select ".tz-row", 3
    assert_select ".tz-row .city", text: "Pacific Time" # Slack's names, not "PDT"
    assert_select ".tz-row .avatar", 0
    assert_select "[data-grid-zones-value*='America/New_York']"
    assert_select "[data-grid-pin-at-value='#{AT}']"
    assert_select ".shared-drift .segmented a[aria-current='page']", I18n.t("boards.as_shared")
    assert_no_match "Priya Rao", css_select(".tz-row").text
  end

  test "the switch keeps only the board's own parameters" do
    get board_path("everyone", date: "2026-10-16", pin: AT, shared_z: "America/New_York", shared_at: MADE, host: "evil.example", anchor: "x")
    css_select(".shared-drift .segmented a").each do |a|
      assert a["href"].start_with?("/boards/everyone?"), a["href"]
      assert_no_match(/evil|anchor|#x/, a["href"])
    end
  end

  test "unknown zones and nonsense times are ignored" do
    get board_path("everyone", shared_z: "Mars/Olympus,#{NOW_ZONES}", shared_at: MADE)
    assert_select ".shared-drift", 0
    get board_path("everyone", shared_z: "America/New_York", shared_at: "soon")
    assert_select ".shared-drift", 0
  end

  test "signed-out viewers see when the link was made" do
    delete sign_out_path
    get moment_path(AT, z: NOW_ZONES, tz: "America/Los_Angeles", g: MADE)
    assert_select "p", /#{Regexp.escape(I18n.t("moments.shared_on", date: "Mon, Oct 12"))}/
  end
end
