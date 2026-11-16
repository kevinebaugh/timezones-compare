require "test_helper"

# Every language file matches English: the same keys, the same %{placeholders},
# and the plural forms its language needs. Regional variants (en-GB, es-419,
# fr-CA) only override what differs, so they're checked for stray keys only.
class TranslationsTest < ActiveSupport::TestCase
  ROOT = Rails.root.join("config/locales")
  PLURAL_FORMS = %w[zero one two few many other].freeze
  # Formats are locale-specific patterns, not text, so they may differ freely.
  FORMAT_KEYS = %w[date.formats time.formats].freeze

  def self.flatten(hash, prefix = nil)
    hash.each_with_object({}) do |(key, value), out|
      path = [ prefix, key ].compact.join(".")
      if value.is_a?(Hash) && !(value.keys.map(&:to_s) - PLURAL_FORMS).empty?
        out.merge!(flatten(value, path))
      else
        out[path] = value
      end
    end
  end

  def self.load(code) = YAML.load_file(ROOT.join("#{code}.yml")).fetch(code)

  ENGLISH = flatten(load("en"))

  def placeholders(value)
    Array(value.is_a?(Hash) ? value.values : value).flat_map { it.to_s.scan(/%\{(\w+)\}/) }.flatten.uniq.sort
  end

  def plural_keys(code)
    rule = I18n.t(:"i18n.plural.rule", locale: code, resolve: false)
    return %w[one other] unless rule.respond_to?(:call)
    (0..200).map { rule.call(it) }.push(rule.call(1.5)).uniq.map(&:to_s).sort
  end

  test "every language has a file" do
    (Languages::CODES - [ "en" ]).each { assert ROOT.join("#{it}.yml").exist?, "missing config/locales/#{it}.yml" }
  end

  (Languages::CODES - [ "en" ]).each do |code|
    test "#{code} matches English" do
      skip "no file yet" unless ROOT.join("#{code}.yml").exist?
      theirs = self.class.flatten(self.class.load(code))
      variant = Languages::VARIANTS.key?(code)

      extra = theirs.keys - ENGLISH.keys
      assert_empty extra, "#{code} has keys English doesn't"
      unless variant
        missing = ENGLISH.keys - theirs.keys
        assert_empty missing, "#{code} is missing keys"
      end

      theirs.each do |key, value|
        next if FORMAT_KEYS.any? { key.start_with?(it) }
        assert_equal placeholders(ENGLISH[key]), placeholders(value), "#{code} #{key} placeholders"
        if ENGLISH[key].is_a?(Hash)
          assert_kind_of Hash, value, "#{code} #{key} should be pluralized"
          assert_equal plural_keys(code), value.keys.map(&:to_s).sort, "#{code} #{key} plural forms"
        end
      end
    end
  end
end
