require "application_system_test_case"

class TabsOverflowSystemTest < ApplicationSystemTestCase
  setup do
    visit root_path
    click_on "Try the demo"
    assert_current_path %r{/boards/everyone}
    # Open a few channels so there are more tabs than a phone can show.
    %w[general launches random].each { visit board_path("~#{it}") }
  end

  teardown { page.driver.browser.manage.window.resize_to(1400, 1000) }

  def tabs_state
    page.evaluate_script(<<~JS)
      (() => { const nav = document.querySelector(".board-tabs");
               return { scroll: nav.scrollWidth, width: nav.clientWidth,
                        shown: [...nav.querySelectorAll(":scope > a:not([hidden])")].map(a => a.textContent.trim()),
                        hidden: nav.querySelectorAll(":scope > a[hidden]").length,
                        more: nav.querySelector(".tabs-more").textContent.trim() } })()
    JS
  end

  test "on a wide screen every tab shows and the menu says More" do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    visit board_path("everyone")
    state = tabs_state
    assert_equal 0, state["hidden"]
    assert_equal I18n.t("boards.more"), state["more"]
    assert_operator state["scroll"], :<=, state["width"] + 1
  end

  test "on a phone, tabs that don't fit fold into +N more, listed under Your tabs" do
    page.driver.browser.manage.window.resize_to(390, 900)
    visit board_path("~random")
    state = tabs_state
    assert_operator state["hidden"], :>, 0
    assert_operator state["scroll"], :<=, state["width"] + 1, "never scrolls sideways"
    assert_includes state["shown"].join(" "), "random", "the current board stays visible"
    assert_match(/Demo Co/, state["shown"].first)
    assert_equal "+#{state["hidden"]} more", state["more"]

    find(".tabs-more").click
    assert_selector ".groups-heading[data-section='your_tabs']", text: /#{Regexp.escape(I18n.t("boards.your_tabs_heading"))}/i
    assert_selector ".group-item[data-section='your_tabs']:not([hidden])", count: state["hidden"]
  end

  test "on the narrowest phones the tabs that must stay shorten instead of overflowing" do
    page.driver.browser.manage.window.resize_to(320, 800)
    visit board_path("~random")
    state = tabs_state
    assert_operator state["scroll"], :<=, state["width"] + 1, "never scrolls sideways"
    assert_includes state["shown"].join(" "), "random"
  end
end
