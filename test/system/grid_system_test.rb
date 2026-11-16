require "application_system_test_case"

class GridSystemTest < ApplicationSystemTestCase
  setup do
    visit root_path
    click_on "Try the demo"
    assert_current_path %r{/boards/everyone} # the home page has a live board of its own
    assert_selector ".tz-row", minimum: 5
  end

  test "pointing at an hour previews it across every row" do
    first(".tz-row .tz-cell[data-col='10']").hover
    assert_selector ".tz-band:not([hidden])"
    assert_selector ".tz-cell.is-col[data-col='10']", minimum: 5
    assert_selector ".tz-summary:not(.is-idle)", text: /\w{3}, \w{3} \d{1,2} · .+ Pacific Time/
    assert_no_selector ".tz-summary .chip"
    assert_selector ".tz-label .is-preview", minimum: 5

    find(".tz-scroll").hover # still over the grid
    find("h2", text: "Demo Co").hover
    assert_selector ".tz-band", visible: :hidden
    assert_no_selector ".tz-label .is-preview"
  end

  test "hovering never moves the grid on a narrow screen" do
    page.driver.browser.manage.window.resize_to(820, 900)
    visit current_path
    tops, heights = page.evaluate_script(<<~JS)
      (() => {
        const table = document.querySelector(".tz-table")
        const strip = document.querySelector(".tz-strip").getBoundingClientRect()
        const bar = document.querySelector(".tz-summary")
        const n = document.querySelectorAll(".tz-row:first-child .tz-cell").length
        const tops = new Set(), heights = new Set()
        for (let i = 0; i < n; i++) {
          table.dispatchEvent(new PointerEvent("pointermove", { bubbles: true, clientX: strip.left + (i + 0.5) * strip.width / n }))
          tops.add(Math.round(table.getBoundingClientRect().top))
          heights.add(bar.offsetHeight)
        }
        return [[...tops], [...heights]]
      })()
    JS
    assert_equal 1, tops.size, "grid moved while hovering: #{tops}"
    assert_equal 1, heights.size, "summary bar changed height: #{heights}"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  test "click pins, copy is offered, clock toggle updates the line" do
    first(".tz-row .tz-cell[data-col='10']").click
    assert_selector ".tz-band.is-pinned"
    assert_button "Copy times"
    link = find("a", text: "Google Calendar")[:href]
    params = Rack::Utils.parse_query(URI(link).query)
    assert_equal "TEMPLATE", params["action"]
    assert_nil params["text"], "untitled"
    assert_match %r{Created via https://timezones.compare\z}, params["details"]
    assert_match(/^\w{3} \d{1,2}:\d{2} [AP]M · Pacific Time: /, params["details"])
    assert_no_text "Outlook"

    click_on "24h"
    assert_selector "section.clock-24"
    assert_selector ".tz-summary .text", text: / \d{2}:\d{2} /
  end

  # x, y on the board for a given minute after the grid starts.
  def grid_point(minute)
    page.evaluate_script(<<~JS)
      (() => { const s = document.querySelector(".tz-strip").getBoundingClientRect();
               const cols = document.querySelectorAll(".tz-row:first-child .tz-cell").length;
               return [Math.round(s.left + (#{minute} / (cols * 60)) * s.width), Math.round(s.top + s.height / 2)] })()
    JS
  end

  def drag(from_minute, to_minute)
    x1, y = grid_point(from_minute)
    x2, = grid_point(to_minute)
    page.driver.browser.action.move_to_location(x1, y).pointer_down(:left).move_to_location((x1 + x2) / 2, y)
        .move_to_location(x2, y).pointer_up(:left).perform
  end

  test "hovering previews a half hour at the nearest quarter, and a click pins it" do
    x, y = grid_point(9 * 60 + 47) # 9:45-ish into the grid
    page.driver.browser.action.move_to_location(x, y).perform
    assert_selector ".tz-band:not([hidden])"
    assert_equal [ "9.75", "0.5" ], page.evaluate_script("['--start','--span'].map(p => document.querySelector('.tz-band').style.getPropertyValue(p))")

    page.driver.browser.action.move_to_location(x, y).click.perform
    assert_selector ".tz-band.is-pinned"
    assert_selector ".tz-summary .text", text: /· 30 min\z/
  end

  test "press and drag sets the meeting's length in quarter hours, all the way to the calendar invite" do
    drag(9 * 60 + 5, 10 * 60 + 35) # 9:00 through the 10:30 quarter
    assert_selector ".tz-band.is-pinned"
    assert_equal [ "9", "1.75" ], page.evaluate_script("['--start','--span'].map(p => document.querySelector('.tz-band').style.getPropertyValue(p))")
    assert_selector ".tz-summary .text", text: /1 hr,? 45 min|105 min/

    dates = Rack::Utils.parse_query(URI(find("a", text: "Google Calendar")[:href]).query)["dates"]
    start, finish = dates.split("/").map { Time.strptime(it, "%Y%m%dT%H%M%S%z") rescue Time.parse(it) }
    assert_equal 105.minutes, finish - start

    drag(14 * 60 + 40, 13 * 60 + 10) # dragging leftward works too: 13:00 through 14:45
    assert_equal [ "13", "1.75" ], page.evaluate_script("['--start','--span'].map(p => document.querySelector('.tz-band').style.getPropertyValue(p))")
  end

  test "arrow keys move the slot by 15 minutes, and Shift+arrows change its length" do
    find(".tz-table").send_keys(:enter)
    start = page.evaluate_script("Number(document.querySelector('.tz-band').style.getPropertyValue('--start'))")
    find(".tz-table").send_keys(:right)
    assert_in_delta start + 0.25, page.evaluate_script("Number(document.querySelector('.tz-band').style.getPropertyValue('--start'))"), 0.001
    find(".tz-table").send_keys([ :shift, :right ])
    assert_equal "0.75", page.evaluate_script("document.querySelector('.tz-band').style.getPropertyValue('--span')")
  end

  test "Copy link carries the slot's start and length, and opening it pins exactly that" do
    drag(10 * 60 + 20, 11 * 60 + 5) # 10:15 through the 11:00 quarter = 1 hour
    click_on "Copy link"
    link = find("button", text: /Copy link|Copied/)["data-link"]
    assert_match %r{/t/\d+\?z=.*&tz=.*&d=60&b=everyone&g=\d+}, link

    visit URI(link).request_uri
    assert_selector ".tz-band.is-pinned"
    assert_equal [ "10.25", "1" ], page.evaluate_script("['--start','--span'].map(p => document.querySelector('.tz-band').style.getPropertyValue(p))")
    assert_selector ".tz-cell.is-col[data-col='10']", minimum: 5
    assert_selector ".tz-cell.is-col[data-col='11']", minimum: 5
  end

  test "picking a date from the calendar goes to that day" do
    visit board_path("everyone", date: "2026-10-16")
    find(".date-pick-button").click
    assert_selector ".cal-title", text: "October 2026"
    assert_selector ".cal-day.is-selected", text: "16"
    find(".cal-nav[aria-label='Next month']").click
    assert_selector ".cal-title", text: "November 2026"
    find(".cal-day:not(.is-out)", text: /\A10\z/).click
    assert_current_path(/date=2026-11-10/)
    assert_selector ".date-pick-button", text: "Tuesday, November 10"
  end

  test "Escape closes the calendar" do
    find(".date-pick-button").click
    assert_selector ".cal", visible: true
    find("body").send_keys(:escape)
    assert_no_selector ".cal", visible: true
  end

  test "arrow keys move the highlight and Enter pins" do
    find(".tz-table").send_keys(:right)
    assert_selector ".tz-band:not([hidden])"
    find(".tz-table").send_keys(:enter)
    assert_selector ".tz-band.is-pinned"
    find(".tz-table").send_keys(:escape)
    assert_selector ".tz-band", visible: :hidden
  end

  test "zones with only an abbreviation get the browser's name for them" do
    visit moment_path(Time.utc(2026, 10, 28, 14).to_i, z: "America/New_York,Asia/Tokyo,Asia/Dubai", tz: "America/New_York")
    assert_selector ".tz-row .city", text: "Japan Time"
    assert_selector ".tz-row .city", text: "Gulf Time"
    assert_selector ".tz-row .city", text: "Eastern Time"
  end

  test "a picked time that lands on someone's weekend says so, and so do copied times" do
    visit moment_path(Time.utc(2026, 11, 13, 21).to_i, z: "America/New_York,Australia/Sydney", tz: "America/New_York")
    assert_selector ".tz-summary", text: "Weekend for Australian Eastern Time"
    sydney = all(".tz-row").last
    assert sydney.all(".tz-cell.is-off").any?, "Sydney's Saturday is hatched"
    assert_empty all(".tz-row").first.all(".tz-cell.is-off"), "New York's Friday isn't"
    copied = evaluate_script(<<~JS)
      (() => { const el = document.querySelector("[data-controller~='grid']")
               return window.Stimulus.getControllerForElementAndIdentifier(el, "grid").currentSummary })()
    JS
    assert_match(/Sat 8:00\s?AM · Australian Eastern Time \(weekend\)/, copied)
    assert_match(/Fri 4:00\s?PM · Eastern Time$/, copied, "New York isn't on a weekend")
    assert_no_match(/America\/|Australia\//, copied, "shared links never list names")
    assert_selector ".legend .swatch-weekend"
  end
end
