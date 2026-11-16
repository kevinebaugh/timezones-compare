require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "start redirects to Slack with a state" do
    post slack_sign_in_path
    assert_match %r{\Ahttps://slack.com/oauth/v2/authorize\?}, response.location
  end

  test "callback signs in a new person and stores their token encrypted" do
    workspaces(:acme).update!(roster_synced_at: Time.current)
    assert_difference -> { User.count } do
      sign_in_via_slack(user_id: "UNEWBIE", name: "New Bie", tz: "Asia/Tokyo")
    end

    user = User.joins(:member).find_by!(members: { slack_user_id: "UNEWBIE" })
    assert_equal "xoxp-new", user.slack_user_token
    assert_not_includes User.connection.select_value("SELECT slack_user_token FROM users WHERE id = #{user.id}"), "xoxp-new"
    assert_redirected_to board_path("everyone")
  end

  test "the first person from a workspace goes through setup and lands on a complete board" do
    sign_in_via_slack(user_id: "UNEWBIE", name: "New Bie", tz: "Asia/Tokyo", team_id: "TFRESH")
    assert_redirected_to setup_path
    follow_redirect!
    assert_select "[data-controller=setup]", text: /Setting up your board/

    stub_slack("users.list", ok: true, members: [
      slack_user("UNEWBIE", name: "New Bie", tz: "Asia/Tokyo"),
      slack_user("UPAL", name: "Pal", tz: "Europe/Paris")
    ])
    stub_slack("usergroups.list", ok: true, usergroups: [ { id: "SX", name: "Crew", handle: "crew", users: %w[UNEWBIE UPAL], date_update: 1_760_000_000 } ])
    stub_slack("dnd.teamInfo", ok: true, users: {})
    post setup_path
    assert_redirected_to board_path("everyone")

    follow_redirect!
    assert_select ".tz-row", 2
    assert_select ".board-tabs > a", text: /Crew/
  end

  test "a returning person skips setup" do
    workspaces(:acme).update!(roster_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
    assert_redirected_to board_path("everyone")
  end

  test "callback rejects a mismatched state" do
    post slack_sign_in_path
    get slack_callback_path(code: "abc", state: "forged")
    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "returning user refreshes their token" do
    sign_in_via_slack(user_id: "UKEV", token: "xoxp-rotated")
    assert_equal "xoxp-rotated", users(:kev).reload.slack_user_token
  end

  test "sign out" do
    sign_in_via_slack
    delete sign_out_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "a browser can be signed into several workspaces and switch between them" do
    workspaces(:acme).update!(roster_synced_at: Time.current)
    sign_in_via_slack(user_id: "UKEV")
    sign_in_via_slack(user_id: "UOTHER", name: "Kev Elsewhere", team_id: "TOTHER", team_name: "Other Co")
    other = User.joins(:member).find_by!(members: { slack_user_id: "UOTHER" })
    Workspace.find_by!(slack_team_id: "TOTHER").update!(roster_synced_at: Time.current)

    get board_path("everyone")
    assert_select ".account-menu .menu-item.is-current", /Other Co/
    assert_select ".account-menu button.menu-item", /Acme/

    post switch_account_path, params: { user_id: users(:kev).id }
    assert_redirected_to board_path("everyone")
    follow_redirect!
    assert_select ".account-menu .menu-item.is-current", /Acme/

    delete sign_out_path
    assert_equal "Signed out of Acme.", flash[:notice]
    follow_redirect!
    assert_select ".account-menu .menu-item.is-current", /Other Co/
    assert_select ".account-menu button.menu-item", text: /Acme/, count: 0
    assert_equal other.id, session[:user_id]
  end

  test "switching to an account this browser isn't signed into is refused" do
    sign_in_via_slack(user_id: "UKEV")
    stranger = User.create!(member: members(:priya))
    post switch_account_path, params: { user_id: stranger.id }
    assert_response :not_found
  end

  test "sign out of all clears every workspace" do
    sign_in_via_slack(user_id: "UKEV")
    sign_in_via_slack(user_id: "UOTHER", name: "Kev Elsewhere", team_id: "TOTHER", team_name: "Other Co")
    delete sign_out_all_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
    assert_nil session[:user_ids]
  end

  test "sign-in attempts from one address are rate limited" do
    with_counting_cache do
      10.times { post slack_sign_in_path }
      assert_match %r{\Ahttps://slack.com/}, response.location

      post slack_sign_in_path
      assert_redirected_to root_path
      assert_equal "Too many sign-in attempts. Try again in a minute.", flash[:alert]
    end
  end

  test "an account whose person left their org drops off; the others stay" do
    workspaces(:acme).update!(roster_synced_at: Time.current)
    sign_in_via_slack(user_id: "UOTHER", name: "Kev Elsewhere", team_id: "TOTHER", team_name: "Other Co")
    sign_in_via_slack(user_id: "UKEV")
    members(:kev).update_column(:deleted, true)

    Workspace.find_by!(slack_team_id: "TOTHER").update!(roster_synced_at: Time.current)
    get board_path("everyone")
    assert_response :success
    assert_select ".account-menu .menu-item.is-current", /Other Co/
    assert_equal 1, session[:user_ids].size
  end

  private
    # Tests use a null cache, which never counts; count in memory instead.
    def with_counting_cache
      counts = Hash.new(0)
      Rails.cache.singleton_class.define_method(:increment) { |key, amount = 1, **| counts[key] += amount }
      yield
    ensure
      Rails.cache.singleton_class.remove_method(:increment)
    end

  test "Slack guests can't sign in, and their token is handed back" do
    revoke = stub_slack("auth.revoke", ok: true)
    assert_no_difference -> { User.count } do
      sign_in_via_slack(user_id: "UGUEST", name: "Gus", is_restricted: true)
    end
    assert_redirected_to root_path
    assert_equal I18n.t("sessions.guests_not_allowed"), flash[:alert]
    assert_requested revoke
    assert_nil Member.find_by(slack_user_id: "UGUEST")

    get board_path("everyone")
    assert_redirected_to root_path
  end

  test "someone who becomes a guest is signed out, and their token never syncs the roster" do
    sign_in_via_slack
    get board_path("everyone")
    assert_response :success

    kev = members(:kev)
    kev.update!(guest: true)
    get board_path("everyone")
    assert_redirected_to root_path
    assert_not_includes kev.workspace.token_holders, kev.user
  end
end
