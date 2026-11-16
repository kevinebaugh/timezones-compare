# What's changed, from config/changelog.yml: days newest first, each with a
# list of changes marked new, improved or fixed.
module Changelog
  Day = Data.define(:date, :changes) do
    # "2026-10-26", so a day can be linked: /changelog#2026-10-26
    def anchor = date.iso8601
  end
  Change = Data.define(:date, :kind, :text) do
    # "2026-10-26-on-other-days-each-time": the date and the first few words,
    # so links keep working when more changes are added to the same day.
    def anchor = [ date.iso8601, *text.downcase.scan(/[a-z0-9]+/).first(6) ].join("-")
  end
  KINDS = %w[new improved fixed].freeze

  def self.days
    YAML.load_file(Rails.root.join("config/changelog.yml"), permitted_classes: [ Date ]).map do |day|
      date = day.fetch("date")
      Day.new(date:, changes: day.fetch("changes").map { Change.new(date:, kind: it.fetch("kind"), text: it.fetch("text")) })
    end
  end
end
