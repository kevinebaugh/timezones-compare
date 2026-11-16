require "test_helper"

class MemberTest < ActiveSupport::TestCase
  test "reachable window is the inverse of the Slack notification schedule, in local time" do
    assert_equal [ 9 * 60, 23 * 60 ], members(:noor).reachable_minutes # quiet 23:00–09:00 BST
  end

  test "notifications on nearly all day show no window" do
    noor = members(:noor)
    noor.update!(dnd_starts_at: Time.utc(2026, 10, 15, 22, 59), dnd_ends_at: Time.utc(2026, 10, 15, 23, 0))
    assert_nil noor.reachable_minutes
  end

  test "no schedule means no reachable window" do
    assert_nil members(:sam).reachable_minutes
  end

  test "labels prefer full names, then display names" do
    assert_equal "Kev", members(:kev).label, "full name over the display name 'kev'"
    assert_equal "jdoe", Member.new(name: "", display_name: "jdoe").label
  end

  test "Slack falls back to the handle when there's no full name" do
    person = Sources::Slack.new.send(:normalize, { "id" => "U1", "name" => "zhe", "real_name" => "", "profile" => { "real_name" => "" } })
    assert_equal "zhe", person[:name]
  end

  test "people scope excludes bots" do
    assert_not_includes Member.people, members(:bot)
  end
end
