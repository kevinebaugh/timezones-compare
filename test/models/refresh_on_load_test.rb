require "test_helper"

class RefreshOnLoadTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @workspace = workspaces(:acme)
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  test "stale data is refreshed in the background" do
    @workspace.update!(roster_synced_at: 10.minutes.ago, availability_synced_at: 10.minutes.ago)
    assert_enqueued_jobs 1, only: SyncRosterJob do
      assert_enqueued_jobs 1, only: SyncAvailabilityJob do
        @workspace.refresh_if_stale!
      end
    end
  end

  test "fresh data is left alone" do
    @workspace.update!(roster_synced_at: 1.minute.ago, availability_synced_at: 1.minute.ago)
    assert_no_enqueued_jobs { @workspace.refresh_if_stale! }
  end

  test "a burst of page loads queues one refresh per workspace" do
    @workspace.update!(roster_synced_at: 1.hour.ago, availability_synced_at: 1.hour.ago)
    assert_enqueued_jobs 1, only: SyncRosterJob do
      5.times { @workspace.refresh_if_stale! }
    end
  end

  test "the window reopens after five minutes" do
    @workspace.update!(roster_synced_at: 1.hour.ago)
    @workspace.refresh_if_stale!
    travel 6.minutes do
      assert_enqueued_jobs 1, only: SyncRosterJob do
        @workspace.refresh_if_stale!
      end
    end
  end
end
