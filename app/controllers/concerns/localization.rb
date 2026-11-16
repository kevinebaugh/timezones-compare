# Runs every request in the visitor's language: their choice from the footer
# (a cookie) or their browser's Accept-Language.
module Localization
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
    helper_method :current_language_rtl?
  end

  private
    def switch_locale(&action)
      I18n.with_locale(requested_locale, &action)
    end

    def requested_locale
      chosen = cookies[:locale]
      Languages.supported?(chosen) ? chosen : Languages.from_header(request.headers["Accept-Language"])
    end

    def current_language_rtl?
      Languages.rtl?(I18n.locale)
    end
end
