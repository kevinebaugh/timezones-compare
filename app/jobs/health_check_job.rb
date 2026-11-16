# Runs every five minutes (config/recurring.yml) and reports to Sentry, via
# Rails.error, when the one machine is running out of room: memory near the
# 512 MB limit, or background jobs waiting instead of running. One issue per
# kind, so Sentry's "new issue" alert is the warning.
class HealthCheckJob < ApplicationJob
  queue_as :default

  MEMORY_LIMIT_MB = 400
  QUEUE_DELAY = 2.minutes

  class LowMemory < StandardError; end
  class QueueBacklog < StandardError; end

  def perform
    if (rss = memory_mb) && rss > MEMORY_LIMIT_MB
      Rails.error.report(LowMemory.new("Memory at #{rss} MB"), handled: true, severity: :warning, context: { rss_mb: rss })
    end

    if (waiting = oldest_ready_job_age) && waiting > QUEUE_DELAY
      Rails.error.report(QueueBacklog.new("Jobs waiting #{waiting.to_i}s"), handled: true, severity: :warning,
                         context: { waiting_seconds: waiting.to_i, ready: ready_count })
    end
  end

  private
    # This process's resident memory, from Linux's /proc; nil elsewhere.
    def memory_mb
      File.read("/proc/self/status")[/VmRSS:\s+(\d+)/, 1]&.to_i&./(1024)
    rescue Errno::ENOENT
      nil
    end

    def ready_count = SolidQueue::ReadyExecution.count

    def oldest_ready_job_age
      oldest = SolidQueue::ReadyExecution.minimum(:created_at)
      Time.current - oldest if oldest
    end
end
