require "application_system_test_case"

class PeoplePickerSystemTest < ApplicationSystemTestCase
  setup do
    visit root_path
    click_on "Try the demo"
    assert_current_path %r{/boards/everyone}
  end

  test "pick coworkers and compare just them, leaving myself out" do
    find(".people-menu summary").click
    assert_selector "label.person-pick", minimum: 5 # the list loads when the picker opens
    assert_text "#{I18n.t("boards.compare")} (1)" # me, ticked to start
    first("label.person-pick", text: "(you)").click
    assert find(".people-menu button[type=submit]").disabled?

    fill_in placeholder: I18n.t("boards.filter_people"), with: "bea"
    assert_selector "label.person-pick", count: 1
    first("label.person-pick").click
    fill_in placeholder: I18n.t("boards.filter_people"), with: ""
    all("label.person-pick").last.click
    assert_text "#{I18n.t("boards.compare")} (2)"

    click_on "#{I18n.t("boards.compare")} (2)"
    assert_current_path %r{/boards/people\?}
    assert_selector ".board-tabs > a.is-visiting", text: /👤/
    assert_selector ".tz-row", count: 2 # bea in Pacific, lou in Australia; not me
    assert_no_text "ada (you)"
  end

  test "dropdown lists scroll on their own, and the wordmark has no gap" do
    find(".people-menu summary").click
    assert_selector "label.person-pick", minimum: 1
    assert_equal "contain", evaluate_script("getComputedStyle(document.querySelector('.people-menu .groups-list')).overscrollBehaviorY")
    gap = evaluate_script(<<~JS)
      (() => { const w = document.querySelector(".wordmark"); const s = w.querySelector("span").getBoundingClientRect();
               const r = document.createRange(); r.selectNodeContents(w.firstChild); return Math.round(s.left - r.getBoundingClientRect().right) })()
    JS
    assert_operator gap, :<=, 1
  end

  test "Clear goes back to just me, and picked people are listed right after me" do
    find(".people-menu summary").click
    assert_selector "label.person-pick", minimum: 5
    all("label.person-pick").last.click
    assert_text "#{I18n.t("boards.compare")} (2)"
    click_on "#{I18n.t("boards.compare")} (2)"
    assert_current_path %r{/boards/people\?}

    find(".people-menu summary").click
    picks = all("label.person-pick input").first(2)
    assert picks.all?(&:checked?), "me, then the person I picked"
    click_on I18n.t("boards.clear")
    assert_text "#{I18n.t("boards.compare")} (1)"
    assert_equal 1, all("label.person-pick input:checked", visible: :all).size
  end

  test "typing a name into the groups and channels menu finds the person" do
    find(".board-tabs .tabs-more").click
    filter = find(".board-tabs .groups-filter")
    assert_no_selector ".board-tabs a.person-pick", visible: true # nobody until you type
    filter.fill_in with: "bea"
    assert_selector ".board-tabs a.person-pick", text: "bea"
    filter.send_keys(:enter)
    assert_current_path %r{/boards/people\?p=}
    assert_selector ".tz-row", minimum: 1
  end
end
