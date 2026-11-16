require "test_helper"

class PreviewsControllerTest < ActionDispatch::IntegrationTest
  test "signed out, the home page shows the real board for a sample team" do
    get root_path
    assert_select "turbo-frame#home-preview .home-preview[data-controller='preview']" do
      assert_select "section[data-controller='grid'] .tz-row", 11
      assert_select ".avatar img[src^='/preview-avatars/'][alt='Maya Okafor']"
      assert_select ".avatar-more", minimum: 1
      assert_select ".tz-block", minimum: 6
      assert_select "a[aria-label='Next day'][href^='/preview?date=']"
    end
  end

  test "the preview redraws for the visitor's zone and day, inside its frame" do
    get home_preview_path(tz: "Asia/Tokyo", date: "2026-10-20")
    assert_response :success
    assert_select "turbo-frame#home-preview"
    assert_select ".tz-row.is-reference .city", text: /JST|Japan|UTC\+9/
    assert_select "summary.date-pick-button", /October 20/
    assert_no_match(/<html/, response.body)
  end
end
