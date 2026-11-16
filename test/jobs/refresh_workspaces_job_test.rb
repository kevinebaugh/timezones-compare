require "test_helper"

class RefreshWorkspacesJobTest < ActiveJob::TestCase
  setup do
    @workspace = workspaces(:acme)
    assert_includes Workspace.with_token_holders, @workspace
  end

  test "a workspace opened lately is refreshed every hour" do
    @workspace.update!(last_viewed_at: 1.day.ago, roster_synced_at: 30.minutes.ago)
    assert_enqueued_with(job: SyncRosterJob, args: [ @workspace ]) { RefreshWorkspacesJob.perform_now }
  end

  test "a quiet workspace is refreshed once a day" do
    @workspace.update!(last_viewed_at: 30.days.ago, roster_synced_at: 2.hours.ago)
    RefreshWorkspacesJob.perform_now
    assert_no_enqueued_jobs(only: SyncRosterJob, queue: "default") { RefreshWorkspacesJob.perform_now }

    @workspace.update!(roster_synced_at: 25.hours.ago)
    assert_enqueued_with(job: SyncRosterJob, args: [ @workspace ]) { RefreshWorkspacesJob.perform_now }
  end

  test "opening a board marks the workspace active, writing at most hourly" do
    @workspace.update!(last_viewed_at: nil)
    @workspace.touch_viewed
    assert @workspace.reload.active?
    assert_no_changes(-> { @workspace.reload.last_viewed_at }) { @workspace.touch_viewed }
  end
end
