require "test_helper"

class LinkPreviewBotsTest < ActionDispatch::IntegrationTest
  APPLE_PREVIEW = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_1) AppleWebKit/601.2.4 (KHTML, like Gecko) Version/9.0.1 Safari/601.2.4 facebookexternalhit/1.1 Facebot Twitterbot/1.0"
  OLD_SAFARI = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_1) AppleWebKit/601.2.4 (KHTML, like Gecko) Version/9.0.1 Safari/601.2.4"

  test "Apple's link preview fetcher gets the page and its preview tags" do
    get root_path, headers: { "User-Agent" => APPLE_PREVIEW }
    assert_response :success
    assert_select "meta[property='og:image']"
  end

  test "a genuinely old browser still gets the upgrade page" do
    get root_path, headers: { "User-Agent" => OLD_SAFARI }
    assert_response :not_acceptable
  end

  test "favicon.ico points at the icon" do
    get "/favicon.ico"
    assert_redirected_to "/icon.png"
  end
end
