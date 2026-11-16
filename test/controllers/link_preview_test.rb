require "test_helper"

class LinkPreviewTest < ActionDispatch::IntegrationTest
  def png_size(path)
    File.binread(Rails.root.join("public", path), 24)[16, 8].unpack("NN")
  end

  test "the home page has a full link preview with absolute URLs" do
    get root_path
    assert_select "meta[property='og:title'][content^='timezones.compare']"
    assert_select "meta[property='og:description'][content*='working hours']"
    assert_select "meta[property='og:image'][content='http://www.example.com/og.png']"
    assert_select "meta[property='og:image:width'][content='1200']"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    assert_select "meta[name='slack-app-id'][content='A0C9EHJM64D']"
    assert_select "link[rel='canonical'][href='http://www.example.com/']"
    assert_select "link[rel='apple-touch-icon'][href='/apple-touch-icon.png']"
  end

  test "APP_URL pins previews to the public domain" do
    ENV["APP_URL"] = "https://timezones.compare"
    get root_path
    assert_select "meta[property='og:image'][content='https://timezones.compare/og.png']"
    assert_select "meta[property='og:url'][content='https://timezones.compare/']"
  ensure
    ENV.delete("APP_URL")
  end

  test "preview images are the sizes the tags promise" do
    assert_equal [ 1200, 630 ], png_size("og.png")
    assert_equal [ 180, 180 ], png_size("apple-touch-icon.png")
    assert_equal [ 512, 512 ], png_size("icon.png")
  end
end
