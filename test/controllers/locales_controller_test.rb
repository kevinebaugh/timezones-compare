require "test_helper"

class LocalesControllerTest < ActionDispatch::IntegrationTest
  test "the browser's language is used, with lang and dir on the page" do
    get root_path, headers: { "Accept-Language" => "de-DE,de;q=0.9" }
    assert_select "html[lang='de'][dir='ltr']"
    assert_select "h1", /Zeitzonen|Zeit/

    get root_path, headers: { "Accept-Language" => "ar" }
    assert_select "html[lang='ar'][dir='rtl']"
  end

  test "choosing a language in the footer sticks and goes back where you were" do
    patch locale_path, params: { locale: "ja" }, headers: { "Referer" => "http://www.example.com/support" }
    assert_redirected_to "/support"
    get support_path, headers: { "Accept-Language" => "en" }
    assert_select "html[lang='ja']"
    assert_select "summary.lang-trigger", /日本語/
  end

  test "unknown languages are ignored and redirects stay on this site" do
    patch locale_path, params: { locale: "xx" }, headers: { "Referer" => "https://evil.example/phish" }
    assert_redirected_to "/phish"
    assert_nil cookies[:locale].presence

    patch locale_path, params: { locale: "fr" }, headers: { "Referer" => "//evil.example" }
    assert_redirected_to root_path
  end

  test "every language renders the home, board and support pages" do
    sign_in_via_slack(user_id: "UKEV")
    Languages::CODES.each do |code|
      patch locale_path, params: { locale: code }
      [ board_path("everyone"), support_path, privacy_path ].each do |path|
        get path
        assert_response :success, "#{code} #{path}"
        assert_select "html[lang='#{code}']"
      end
    end
  end

  test "the privacy policy stays in English, with a note in other languages" do
    patch locale_path, params: { locale: "fr" }
    get privacy_path
    assert_select "article[lang='en'] h1", "Privacy"
    assert_select ".page-note[lang='fr']"
  end
end
