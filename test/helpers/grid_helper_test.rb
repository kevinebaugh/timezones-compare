require "test_helper"

class GridHelperTest < ActionView::TestCase
  test "each avatar names its person, and +N lists who it stands for" do
    people = %i[kev sam noor priya].map { members(it) }
    html = Nokogiri::HTML5.fragment(avatar_stack(people, limit: 2))

    assert_equal [ people[0].label, people[1].label ], html.css(".avatar:not(.avatar-more)").map { it["title"] }
    more = html.at_css(".avatar-more")
    assert_equal "+2", more.text
    assert_equal "#{people[2].label}\n#{people[3].label}", more["title"]
    assert_equal "and #{people[2].label} and #{people[3].label}", more["aria-label"]
  end

  test "no +N when everyone fits" do
    html = Nokogiri::HTML5.fragment(avatar_stack([ members(:kev) ]))
    assert_nil html.at_css(".avatar-more")
  end

  test "an avatar URL that isn't https shows initials instead of failing the page" do
    member = members(:sam)
    member.avatar_url = "javascript:alert(1)"
    html = Nokogiri::HTML5.fragment(avatar(member))

    assert_nil html.at_css("img")
    assert_equal "SL", html.at_css(".avatar").text
  end

  test "Slack's https avatars and the sample team's own files are shown" do
    member = members(:sam)
    [ "https://avatars.slack-edge.com/sam.png", "/preview-avatars/sam-lee.svg" ].each do |url|
      member.avatar_url = url
      assert_equal url, Nokogiri::HTML5.fragment(avatar(member)).at_css("img")["src"]
    end
  end
end
