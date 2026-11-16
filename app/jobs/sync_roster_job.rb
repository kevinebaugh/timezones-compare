class SyncRosterJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(workspace) { "roster-#{workspace.id}" }
  retry_on Sources::Base::RateLimited, wait: ->(_executions) { 1.minute }, attempts: 5

  def perform(workspace)
    workspace.sync_roster!
  end
end
