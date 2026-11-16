require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "pages send a content security policy that only runs this site's scripts" do
    get root_path
    csp = response.headers["Content-Security-Policy"]

    assert_match %r{script-src 'self' https://static\.cloudflareinsights\.com 'nonce-[^']+'}, csp
    assert_includes csp, "object-src 'none'"
    assert_includes csp, "frame-ancestors 'none'"
    assert_includes csp, "base-uri 'self'"
    assert_includes csp, "form-action 'self' https://slack.com https://*.slack.com"
  end

  test "the importmap's inline scripts carry the nonce" do
    get root_path
    nonce = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]

    scripts = css_select("script:not([src])")
    assert scripts.any?
    scripts.each { assert_equal nonce, it["nonce"] }
  end

  test "the Cloudflare Web Analytics beacon is allowed to load and report" do
    ENV["CLOUDFLARE_WEB_ANALYTICS_TOKEN"] = "abc123"
    get root_path
    csp = response.headers["Content-Security-Policy"]
    nonce = csp[/'nonce-([^']+)'/, 1]

    assert_match %r{script-src [^;]*https://static\.cloudflareinsights\.com}, csp
    assert_match %r{connect-src [^;]*https://cloudflareinsights\.com}, csp
    assert_select "script[src='https://static.cloudflareinsights.com/beacon.min.js'][nonce=?]", nonce
  ensure
    ENV.delete("CLOUDFLARE_WEB_ANALYTICS_TOKEN")
  end

  test "the OAuth code and state never reach the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter("code" => "1234.5678", "state" => "abc", "z" => "UTC", "tz" => "UTC")

    assert_equal "[FILTERED]", filtered["code"]
    assert_equal "[FILTERED]", filtered["state"]
    assert_equal "UTC", filtered["z"]
    assert_equal "UTC", filtered["tz"]
  end
end
