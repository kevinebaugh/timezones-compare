require "test_helper"

class MomentsControllerTest < ActionDispatch::IntegrationTest
  AT = Time.utc(2026, 10, 16, 17).to_i # 10:00 AM PDT
  ZONES = "America/Los_Angeles,Europe/London,Asia/Kolkata"

  test "anyone can open a shared moment: zones and the pinned hour, no names" do
    get moment_path(AT, z: ZONES, tz: "America/Los_Angeles")
    assert_response :success
    assert_select "h1", "Fri, Oct 16 at 10:00 AM PDT"
    assert_select ".tz-row", 3
    assert_select "[data-grid-pin-at-value='#{AT}']"
    assert_select ".avatar", 0
    assert_select ".tz-notif", 0
    assert_select "button", text: "Sign in with Slack"
  end

  test "its link preview names the moment and each zone's time" do
    get moment_path(AT, z: ZONES, tz: "America/Los_Angeles")
    assert_select "meta[property='og:title'][content='Fri, Oct 16 at 10:00 AM PDT']"
    assert_select "meta[property='og:description'][content='10:00 AM PDT · 6:00 PM BST · 10:30 PM IST']"
  end

  test "the link preview says when the time is someone's weekend" do
    friday_4pm_eastern = Time.utc(2026, 11, 13, 21).to_i
    get moment_path(friday_4pm_eastern, z: "America/New_York,Australia/Sydney", tz: "America/New_York")
    assert_select "meta[property='og:description'][content='4:00 PM EST · Sat 8:00 AM AEDT (weekend)']"
  end

  test "teammates who can see the board land on it with the hour pinned" do
    workspaces(:acme).update!(roster_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
    get moment_path(AT, z: ZONES, tz: "America/Los_Angeles", b: "mobile-team")
    assert_redirected_to board_path("mobile-team", date: "2026-10-16", tz: "America/Los_Angeles", pin: AT)
  end

  test "people who can't see the board get the public view" do
    workspaces(:acme).update!(roster_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
    get moment_path(AT, z: ZONES, tz: "America/Los_Angeles", b: "no-such-group")
    assert_response :success
    assert_select ".tz-row", 3
  end

  test "a teammate who isn't in the group still lands on its board, as any full member can see it" do
    workspaces(:acme).update!(roster_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
    get moment_path(AT, z: ZONES, tz: "America/Los_Angeles", b: "leadership")
    assert_redirected_to %r{/boards/leadership\?}
  end

  test "signing in from a shared moment comes back to it" do
    workspaces(:acme).update!(roster_synced_at: Time.current)
    get moment_path(AT, z: ZONES, b: "mobile-team")
    sign_in_via_slack(user_id: "UKEV")
    assert_redirected_to moment_path(AT, z: ZONES, b: "mobile-team")
  end

  test "bad links are not found" do
    get moment_path(AT, z: "Mars/Olympus")
    assert_response :not_found
    get moment_path(99_999_999_999, z: ZONES)
    assert_response :not_found
  end

  test "board pages pin an hour from the link" do
    workspaces(:acme).update!(roster_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
    get board_path("mobile-team", date: "2026-10-16", pin: AT)
    assert_select "[data-grid-pin-at-value='#{AT}'][data-grid-board-key-value='mobile-team']"
  end

  test "a slot link at a quarter hour, with a length, shows and pins exactly that" do
    at = AT + 15.minutes.to_i # 10:15 AM PDT
    get moment_path(at, z: ZONES, tz: "America/Los_Angeles", d: 45)
    assert_select "h1", "Fri, Oct 16 at 10:15 AM–11:00 AM PDT"
    assert_select "[data-grid-pin-at-value='#{at}'][data-grid-pin-minutes-value='45']"
    assert_select "meta[property='og:description'][content*='10:15 AM']"
  end

  test "odd lengths are ignored, and teammates land on the board with the length kept" do
    get moment_path(AT, z: ZONES, tz: "America/Los_Angeles", d: 50)
    assert_select "[data-grid-pin-minutes-value='']"

    workspaces(:acme).update!(roster_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
    get moment_path(AT, z: ZONES, tz: "America/Los_Angeles", d: 90, b: "everyone")
    assert_redirected_to %r{/boards/everyone\?.*d=90}
    follow_redirect!
    assert_select "[data-grid-pin-minutes-value='90']"
  end
end
