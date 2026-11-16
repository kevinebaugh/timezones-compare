require "test_helper"

class HealthCheckJobTest < ActiveJob::TestCase
  test "quiet when memory and the queue are fine" do
    assert_no_error_reported { checked(memory: 200, waiting: 5.seconds).perform }
  end

  test "reports high memory" do
    assert_error_reported(HealthCheckJob::LowMemory) { checked(memory: 450, waiting: nil).perform }
  end

  test "reports jobs left waiting" do
    assert_error_reported(HealthCheckJob::QueueBacklog) { checked(memory: nil, waiting: 5.minutes).perform }
  end

  private
    def checked(memory:, waiting:)
      HealthCheckJob.new.tap do |job|
        job.define_singleton_method(:memory_mb) { memory }
        job.define_singleton_method(:oldest_ready_job_age) { waiting }
        job.define_singleton_method(:ready_count) { 3 }
      end
    end
end
