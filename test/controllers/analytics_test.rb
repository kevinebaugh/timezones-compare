require "test_helper"

class AnalyticsTest < ActionDispatch::IntegrationTest
  BEACON = "script[src='https://static.cloudflareinsights.com/beacon.min.js']"

  test "Cloudflare Web Analytics loads only when a token is set" do
    get root_path
    assert_select BEACON, 0

    ENV["CLOUDFLARE_WEB_ANALYTICS_TOKEN"] = "abc123"
    get root_path
    assert_select "#{BEACON}[data-cf-beacon='{\"token\":\"abc123\"}'][defer]"
  ensure
    ENV.delete("CLOUDFLARE_WEB_ANALYTICS_TOKEN")
  end

  test "the privacy policy discloses it" do
    get privacy_path
    assert_match "Cloudflare Web Analytics", response.body
    assert_no_match(/no ads, analytics/, response.body)
  end
end
