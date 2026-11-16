# Every language Slack lists, by I18n locale, named in its own language.
# The browser's Accept-Language picks one; a cookie remembers a choice made
# in the footer. Regional variants (en-GB, fr-CA, es-419) fall back to their
# base language and only override what differs.
module Languages
  NAMES = {
    "ar" => "العربية", "ca" => "Català", "cs" => "Čeština", "da" => "Dansk", "de" => "Deutsch",
    "el" => "Ελληνικά", "en" => "English (US)", "en-GB" => "English (UK)", "es" => "Español (España)",
    "es-419" => "Español (Latinoamérica)", "fi" => "Suomi", "fr" => "Français (France)",
    "fr-CA" => "Français (Canada)", "he" => "עברית", "hi" => "हिन्दी", "hr" => "Hrvatski", "hu" => "Magyar",
    "id" => "Bahasa Indonesia", "it" => "Italiano", "ja" => "日本語", "ko" => "한국어", "ms" => "Bahasa Melayu",
    "nb" => "Norsk", "nl" => "Nederlands", "pl" => "Polski", "pt" => "Português (Portugal)",
    "pt-BR" => "Português (Brasil)", "ro" => "Română", "sk" => "Slovenčina", "sv" => "Svenska", "th" => "ไทย",
    "tr" => "Türkçe", "uk" => "Українська", "vi" => "Tiếng Việt", "zh-CN" => "简体中文", "zh-TW" => "繁體中文"
  }.freeze
  CODES = NAMES.keys.freeze
  DEFAULT = "en"
  RTL = %w[ar he].freeze
  # Where people usually read a 12-hour clock; everywhere else defaults to 24.
  TWELVE_HOUR = %w[en ar el hi ko ms zh-TW].freeze
  VARIANTS = { "en-GB" => "en", "es-419" => "es", "fr-CA" => "fr" }.freeze

  def self.supported?(code) = CODES.include?(code.to_s)
  def self.rtl?(code) = RTL.include?(code.to_s)
  def self.twelve_hour?(code) = TWELVE_HOUR.include?(code.to_s)

  # Choose from an Accept-Language header, honoring q-values and regions.
  def self.from_header(header)
    tags = header.to_s.split(",").filter_map do |part|
      tag, *params = part.strip.split(";")
      weight = params.find { it.strip.start_with?("q=") }
      q = weight ? weight.split("=").last.to_f : 1.0
      [ tag.strip.downcase, q ] if tag.present? && tag != "*" && q.positive?
    end
    tags.sort_by { -it.last }.each { |(tag, _)| (code = match(tag)) && (return code) }
    DEFAULT
  end

  def self.match(tag)
    return "pt-BR" if tag == "pt" # a bare "pt" most often means Brazil
    exact = CODES.find { it.downcase == tag }
    return exact if exact

    base, region = tag.split("-", 2)
    case base
    when "zh" then region.to_s.match?(/\A(hant|tw|hk|mo)/) ? "zh-TW" : "zh-CN"
    when "pt" then region == "pt" ? "pt" : "pt-BR"
    when "es" then region.nil? || region == "es" ? "es" : "es-419"
    when "fr" then region == "ca" ? "fr-CA" : "fr"
    when "en" then %w[gb ie au nz].include?(region) ? "en-GB" : "en"
    when "no", "nn", "nb" then "nb"
    when "iw" then "he"
    when "in" then "id"
    else CODES.find { it.downcase == base }
    end
  end
end
