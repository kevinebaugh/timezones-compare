require "application_system_test_case"

class HomePreviewSystemTest < ApplicationSystemTestCase
  test "the home page's live board drifts across the hours until you point at it" do
    visit root_path
    assert_selector ".home-preview .tz-band:not([hidden])"
    first_hour = find(".home-preview .tz-summary .text").text
    assert_no_selector ".home-preview .tz-summary .text", text: first_hour, exact_text: true, wait: 4

    find(".home-preview .tz-row:first-child .tz-cell[data-col='3']").hover
    pointed = find(".home-preview .tz-summary .text").text
    sleep 2
    assert_equal pointed, find(".home-preview .tz-summary .text").text, "autoplay stopped for the visitor"
  end
end
