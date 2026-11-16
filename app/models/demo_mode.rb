# Lets you sign in as a seeded fake person without a Slack app. Never
# available in production.
module DemoMode
  WORKSPACE_ID = "TDEMO"

  def self.enabled?
    return false if Rails.env.production?
    ENV["FAKE_SLACK"] == "1" || !Sources::Slack.new.configured?
  end

  def self.workspace
    Workspace.find_by(slack_team_id: WORKSPACE_ID) || begin
      Rails.application.load_seed
      Workspace.find_by!(slack_team_id: WORKSPACE_ID)
    end
  end
end
