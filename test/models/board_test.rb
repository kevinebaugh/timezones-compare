require "test_helper"

class BoardTest < ActiveSupport::TestCase
  setup { @kev = users(:kev) }

  test "the workspace first, then groups I open most, then groups active in Slack" do
    groups(:leadership).group_memberships.create!(member: members(:kev))
    dormant = Group.create!(workspace: workspaces(:acme), slack_group_id: "SAI", name: "Data Team", handle: "data-team", slack_updated_at: 2.years.ago)
    dormant.group_memberships.create!(member: members(:kev))
    groups(:leadership).update!(slack_updated_at: 1.day.ago)
    groups(:platform).update!(slack_updated_at: 1.month.ago)

    assert_equal [ "Acme", "Leadership", "Mobile Team", "Data Team" ], Board.all_for(@kev).map(&:name)

    BoardVisit.record!(@kev, "data-team")
    BoardVisit.record!(@kev, "data-team")
    assert_equal "Leadership", Board.all_for(@kev).second.name, "tabs hold still for the rest of the day"
    assert_equal "Data Team", Board.all_for(@kev, today: Date.tomorrow).second.name, "and reorder the next day"
  end

  test "a group joined mid-day goes at the end; one left drops out" do
    Board.all_for(@kev)
    fresh = Group.create!(workspace: workspaces(:acme), slack_group_id: "SNEW", name: "Aardvarks", handle: "aardvarks", slack_updated_at: Time.current)
    fresh.group_memberships.create!(member: members(:kev))
    assert_equal [ "Acme", "Mobile Team", "Aardvarks" ], Board.all_for(@kev).map(&:name)

    groups(:platform).group_memberships.where(member: members(:kev)).delete_all
    assert_equal [ "Acme", "Aardvarks" ], Board.all_for(@kev).map(&:name)
  end

  test "visits fade with a one-week half-life" do
    visit = BoardVisit.record!(@kev, "mobile-team", at: 2.weeks.ago) && BoardVisit.last
    assert_in_delta 0.25, visit.decayed_score, 0.01
  end

  test "Everyone leaves out guests and bots but always includes me" do
    members(:sam).update!(guest: true)
    members(:kev).update!(guest: true)
    names = Board.everyone(@kev).members.map(&:name)
    assert_includes names, "Kev"
    assert_not_includes names, "Sam Lee"
    assert_not_includes names, "Deploy Bot"
  end

  test "the whole-workspace board is named after the workspace" do
    assert_equal "Acme", Board.everyone(@kev).name
  end

  test "find_for finds any group in my workspace, and knows whether I'm in it" do
    assert Board.find_for(@kev, "mobile-team").member?
    leadership = Board.find_for(@kev, "leadership")
    assert_equal "Leadership", leadership.name
    assert_not leadership.member?
    assert_nil Board.find_for(@kev, "no-such-group")
    assert Board.find_for(@kev, "everyone").everyone?
  end

  test "others_for lists groups I'm not in, with how many people each has" do
    others = Board.others_for(@kev)
    assert_equal [ [ "Leadership", 1 ] ], others[:groups].map { |board, count| [ board.name, count ] }
    assert_empty others[:your_channels]
    assert_empty others[:channels]
  end
end
