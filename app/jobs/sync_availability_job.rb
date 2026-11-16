class SyncAvailabilityJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(workspace) { "availability-#{workspace.id}" }
  retry_on Sources::Base::RateLimited, wait: ->(_executions) { 1.minute }, attempts: 3

  def perform(workspace)
    workspace.sync_availability!
  end
end
