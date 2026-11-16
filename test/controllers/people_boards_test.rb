require "test_helper"

class PeopleBoardsTest < ActionDispatch::IntegrationTest
  setup do
    workspaces(:acme).update!(roster_synced_at: Time.current, availability_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
  end

  test "a board of exactly the people in the link, me included when picked" do
    get board_path("people", p: "UPRIYA,UNOOR,UKEV")
    assert_response :success
    assert_select ".board-tabs > a.is-visiting[aria-current='page']", /👤.*Noor Aziz, Priya Rao/m
    assert_select ".tz-row", 3 # Kev in Pacific, Noor in London, Priya in Kolkata
    assert_select "section", /#{Regexp.escape(I18n.t("boards.picked_note"))}/
    assert_select "a[aria-label='#{I18n.t("grid.next_day")}'][href*='p=UKEV%2CUNOOR%2CUPRIYA']"
    assert_not BoardVisit.exists?(board_key: "people"), "picked boards never become tabs"
  end

  test "a link can leave me out, so it shows only the others" do
    get board_path("people", p: "UPRIYA,UNOOR")
    assert_response :success
    assert_select ".tz-row", 2 # Noor in London, Priya in Kolkata; no Pacific row for me
    assert_select ".tz-row .city", text: /Pacific/, count: 0
  end

  test "a board of just me is named after me" do
    get board_path("people", p: "UKEV")
    assert_response :success
    assert_select ".tz-row", 1
  end

  test "picks also arrive as a list from the picker form, and strangers or nonsense are ignored" do
    get board_path("people", p: %w[UNOOR UNOBODY])
    assert_select ".board-tabs > a.is-visiting", /Noor Aziz/

    get board_path("people", p: "UNOBODY")
    assert_response :not_found
  end

  test "the picker lists coworkers, loads on demand, and ticks the current picks" do
    get board_path("everyone")
    assert_select "details.people-menu turbo-frame#people-picker[loading='lazy'][src='/people_picker']"
    assert_select "details.people-menu form[action='/boards/people'][method='get'] button[disabled]", I18n.t("boards.compare")

    get people_picker_path(p: "UNOOR")
    assert_select "turbo-frame#people-picker label.person-pick input[name='p[]']", 4 # me first, then Sam, Noor and Priya
    assert_select "label.person-pick:first-child input[value='UKEV']:not([checked])", 1, "left out of this link, so unticked"
    assert_select "input[value='UNOOR'][checked]"
    assert_select "input[value='UPRIYA']:not([checked])"
  end

  test "a new comparison starts with me ticked" do
    get people_picker_path
    assert_select "label.person-pick:first-child input[value='UKEV'][checked]"
    assert_select "label.person-pick:first-child", /#{Regexp.escape(I18n.t("boards.you", name: "Kev"))}/
  end

  test "the picker lists me, then whoever's already picked, then everyone else" do
    get people_picker_path(p: "UKEV,UPRIYA")
    names = css_select("label.person-pick input").map { it["value"] }
    assert_equal [ "UKEV", "UPRIYA" ], names.first(2)
    assert_select "label.person-pick:nth-of-type(2) input[checked]"
    assert_select "hr.pick-divider", 1
    assert_select "label.person-pick input[checked]", 2
  end

  test "the groups-and-channels menu finds coworkers too, each opening a board of me and them" do
    get board_path("everyone")
    assert_select ".board-tabs .groups-menu turbo-frame#people-search[loading='lazy'][src='/people_search']"
    assert_select ".board-tabs .groups-filter[placeholder='#{I18n.t("boards.find_boards")}'], .board-tabs .groups-filter[placeholder='#{I18n.t("boards.find_groups")}']"

    get people_search_path
    assert_select "turbo-frame#people-search a.group-item[hidden][data-search-only='true'][data-section='people']", minimum: 1
    assert_select "a[data-name='priya rao'][href='/boards/people?p=UKEV%2CUPRIYA']"
    assert_select "a[href*='p=UKEV%2CUKEV']", 0, "never me"
  end
end
