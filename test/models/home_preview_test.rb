require "test_helper"

class HomePreviewTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 10, 15, 17)

  test "a realistic team: many zones, varied hours, one person with none set" do
    grid = HomePreview.grid("America/New_York", now: NOW)
    assert_equal 11, grid.rows.size
    assert_equal 24, grid.rows.sum { it.members.size }
    assert_equal "Eastern Time", grid.rows.find(&:reference).name
    assert_equal [ "Central Time" ], grid.rows.select { it.blocks.empty? }.map(&:name)
    assert grid.rows.find { it.name == "Pacific Time" }.blocks.any? { !it.everyone? }, "partial overlap shows"
  end

  test "everyone has a full name and a bundled avatar" do
    HomePreview.people.each do |name|
      assert_match(/\A\S+ \S+\z/, name)
      assert Rails.root.join("public", HomePreview.avatar_path(name).delete_prefix("/")).exist?, name
    end
  end

  test "a visitor elsewhere gets their own row as the reference" do
    grid = HomePreview.grid("Asia/Tokyo", now: NOW)
    you = grid.rows.find(&:reference)
    assert_equal "Asia/Tokyo", you.zone.identifier
    assert_equal [ "You" ], you.members.map(&:label)
  end

  test "garbage time zones fall back to Eastern" do
    assert_equal "America/New_York", HomePreview.grid("Mars/Olympus", now: NOW).reference_zone.identifier
  end
end
