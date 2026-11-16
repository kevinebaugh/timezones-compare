# Uncaught JavaScript errors, posted by app/javascript/error_reporter.js and
# passed to Rails.error (Sentry in production). Only the message, source
# location and page path are kept; nothing typed into the page.
class ClientErrorsController < ApplicationController
  skip_before_action :require_user
  skip_forgery_protection
  rate_limit to: 20, within: 1.minute, with: -> { head :too_many_requests }

  class BrowserError < StandardError; end

  def create
    message = params[:message].to_s.truncate(300).presence || "Unknown browser error"
    error = BrowserError.new(message)
    error.set_backtrace([ "#{params[:source].to_s.truncate(200)}:#{params[:line].to_i}:#{params[:column].to_i}" ])
    Rails.error.report(error, handled: true, severity: :error, source: "browser",
                       context: { path: params[:path].to_s.truncate(200), kind: params[:kind].to_s.truncate(30) })
    head :no_content
  end
end
