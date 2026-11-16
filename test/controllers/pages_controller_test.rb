require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "privacy and support are public, with a contact address" do
    %w[/privacy /support].each do |path|
      get path
      assert_response :success
      assert_select "h1"
      assert_select "a[href='mailto:help@timezones.compare']"
    end
  end

  test "the privacy policy names every Slack permission the app asks for" do
    get privacy_path
    Sources::Slack::USER_SCOPES.each { |scope| assert_select "li b", scope }
  end

  test "the contact address can be configured" do
    ENV["SUPPORT_EMAIL"] = "help@example.com"
    get support_path
    assert_select "a[href='mailto:help@example.com']"
  ensure
    ENV.delete("SUPPORT_EMAIL")
  end

  test "a public security summary, linked from support, with security.txt for researchers" do
    get security_path
    assert_response :success
    assert_select "h1", "Security"
    assert_match "No critical or high-severity issues", response.body
    assert_select "a[href='mailto:help@timezones.compare']"

    get support_path
    assert_select "a[href='/security']"

    txt = Rails.root.join("public/.well-known/security.txt").read
    assert_match %r{^Contact: mailto:help@timezones.compare$}, txt
    assert_match %r{^Policy: https://timezones.compare/security$}, txt
    assert Time.iso8601(txt[/^Expires: (.+)$/, 1]) > 3.months.from_now, "security.txt is about to expire"
  end

  test "terms are public, linked from every footer, and point to privacy and security" do
    get terms_path
    assert_response :success
    assert_select "h1", "Terms"
    assert_select "article a[href='/privacy']"
    assert_select "article a[href='/security']"
    assert_select "footer a[href='/terms']"
    Dir[Rails.root.join("public/*.html")].each { assert_includes File.read(it), %(href="/terms"), it }
  end

  test "the privacy policy lists sub-processors at a linkable anchor" do
    get privacy_path
    assert_select "h2#sub-processors"
    assert_select "h2#sub-processors + p + ul li", 3
  end

  test "the changelog lists every day newest first, and every footer links to it" do
    get changelog_path
    assert_response :success
    assert_select "h1", "Changelog"
    dates = css_select(".changelog-day time").map { Date.iso8601(it["datetime"]) }
    assert_equal dates.sort.reverse, dates, "newest first"
    assert_select ".changelog-day li", Changelog.days.sum { it.changes.size }
    assert_match "timezones.compare launches", response.body
    assert_select "footer a[href='/changelog']"
    Dir[Rails.root.join("public/*.html")].each { assert_includes File.read(it), %(href="/changelog"), it }
  end

  test "the security page tells Slack admins what approving the app allows" do
    get security_path
    assert_select "h2#for-admins"
    Sources::Slack::USER_SCOPES.each { |scope| assert_select "#for-admins + p + ul code", text: scope }
  end

  test "the home page points people whose workspace needs approval at the admin notes" do
    get root_path
    assert_select ".admin-note a[href='/security#for-admins']"
  end

  test "the footer's off-site links open in a new tab" do
    get root_path
    assert_select "footer a[href='https://kevinebaugh.com'][target='_blank'][rel~='noopener']"
  end

  test "a deployment can credit where it's tested, from its own settings" do
    with_env("FOOTER_COMPANY_NAME" => "Example Co", "FOOTER_COMPANY_URL" => "https://example.com") do
      get root_path
      assert_select "footer", /Built by Kevin Ebaugh\. Tested at Example Co\./
      assert_select "footer a[href='https://example.com'][target='_blank'][rel~='noopener']", "Example Co"
    end
  end

  test "every changelog day and change has a linkable anchor" do
    get changelog_path
    day = Changelog.days.first
    assert_select "h2##{day.anchor} a[href='##{day.anchor}']"
    change = day.changes.first
    assert_select "li[id='#{change.anchor}'] a.anchor-mark[href='##{change.anchor}']"
    anchors = Changelog.days.flat_map { [ it.anchor, *it.changes.map(&:anchor) ] }
    assert_equal anchors.uniq, anchors, "anchors are unique"
  end

  test "every changelog entry is marked new, improved or fixed" do
    Changelog.days.flat_map(&:changes).each { assert_includes Changelog::KINDS, it.kind, it.text }
  end

  private
    def with_env(vars)
      saved = vars.keys.to_h { [ it, ENV[it] ] }
      vars.each { |k, v| ENV[k] = v }
      yield
    ensure
      saved.each { |k, v| ENV[k] = v }
    end
end
