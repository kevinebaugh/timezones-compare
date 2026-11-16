# Runs hourly (config/recurring.yml): the safety net so departures and group
# changes land even when nobody opens a board. Board loads refresh anything
# older than five minutes (Workspace#refresh_if_stale!). Workspaces nobody has
# opened in two weeks are refreshed once a day instead of every hour.
class RefreshWorkspacesJob < ApplicationJob
  queue_as :default

  # Sentry Crons: an alert if this hourly job stops running (only when Sentry is on).
  if defined?(Sentry::Cron::MonitorCheckIns)
    include Sentry::Cron::MonitorCheckIns
    sentry_monitor_check_ins slug: "refresh-workspaces", monitor_config: Sentry::Cron::MonitorConfig.from_interval(1, :hour)
  end

  def perform
    Workspace.with_token_holders.find_each do |workspace|
      next unless workspace.active? || workspace.roster_synced_at.nil? || workspace.roster_synced_at < 1.day.ago

      SyncRosterJob.perform_later(workspace)
      SyncAvailabilityJob.perform_later(workspace)
    end
  end
end
