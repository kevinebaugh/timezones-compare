# Error tracking with Sentry, on only where SENTRY_DSN is set (production on
# Fly). Self-hosted copies and development stay quiet unless they set one.
#
# Privacy: no names, emails, tokens or request bodies are sent. Events carry an
# internal user id and workspace id (Rails.error.set_context in
# ApplicationController), and request parameters go through the same filters
# as the logs (config/initializers/filter_parameter_logging.rb).
if (dsn = ENV["SENTRY_DSN"].presence)
  Sentry.init do |config|
    config.dsn = dsn
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    config.release = ENV["FLY_IMAGE_REF"].presence || ENV["GIT_SHA"].presence
    config.send_default_pii = false
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f
    config.enabled_environments = %w[production]
  end
end
