require "test_helper"

class NotificationBandTest < ActionDispatch::IntegrationTest
  setup do
    workspaces(:acme).update!(roster_synced_at: Time.current, availability_synced_at: Time.current)
    members(:sam).update!(dnd_enabled: true, dnd_starts_at: Time.utc(2026, 10, 16, 1), dnd_ends_at: Time.utc(2026, 10, 16, 16))
    sign_in_via_slack(user_id: "UKEV")
  end

  test "each row has a working-hours band, in Slack's words" do
    get board_path("mobile-team", date: "2026-10-16")
    assert_select ".tz-row .tz-lanes .tz-notif", 2
    assert_select ".tz-block.is-everyone[title='Working hours: Noor Aziz'] svg.tz-bell"
    assert_select ".legend", /Working hours/
    assert_select ".legend", /from Slack/
    assert_select ".legend", text: /Daylight|Twilight|Night/, count: 0
  end

  test "hours when only some of a zone allow notifications are lighter, with a count" do
    # Los Angeles (PDT): Kev allows 9 am–6 pm, Sam 1 pm–10 pm.
    members(:kev).update!(dnd_enabled: true, dnd_starts_at: Time.utc(2026, 10, 16, 1), dnd_ends_at: Time.utc(2026, 10, 16, 16))
    members(:sam).update!(dnd_starts_at: Time.utc(2026, 10, 16, 5), dnd_ends_at: Time.utc(2026, 10, 16, 20))
    groups(:platform).group_memberships.create!(member: members(:sam))

    get board_path("mobile-team", date: "2026-10-16")
    assert_select ".tz-block.is-some[title='Working hours: Kev'] .tz-block-count", "1 of 2"
    assert_select ".tz-block.is-everyone[title='Working hours: Kev and Sam Lee']"
    assert_select ".tz-block.is-some[title='Working hours: Sam Lee'] .tz-block-count", "1 of 2"
  end

  test "no hour times are repeated inside the band" do
    get board_path("mobile-team", date: "2026-10-16")
    assert_select ".tz-notif", text: /\d{1,2}(:\d{2})? ?(am|pm)/i, count: 0
  end

  test "a zone where nobody has set working hours says so" do
    get board_path("everyone", date: "2026-10-16")
    assert_select ".tz-notif .tz-notif-empty", text: "No working hours set in Slack", minimum: 1
  end
end
