require "test_helper"

class LanguagesTest < ActiveSupport::TestCase
  test "picks the best supported language from Accept-Language" do
    {
      "de-DE,de;q=0.9,en;q=0.8" => "de",
      "en-US,en;q=0.9" => "en",
      "en-GB" => "en-GB",
      "en-AU,en;q=0.5" => "en-GB",
      "pt-PT" => "pt",
      "pt" => "pt-BR",
      "es-MX,es;q=0.9" => "es-419",
      "es-ES" => "es",
      "fr-CA" => "fr-CA",
      "fr-BE" => "fr",
      "zh-Hant-TW" => "zh-TW",
      "zh-HK" => "zh-TW",
      "zh" => "zh-CN",
      "nn-NO" => "nb",
      "iw" => "he",
      "xx-YY,ja;q=0.3" => "ja",
      "ko;q=0.1,sv;q=0.8" => "sv",
      "" => "en",
      "*" => "en"
    }.each { |header, expected| assert_equal expected, Languages.from_header(header), header.inspect }
  end
end
