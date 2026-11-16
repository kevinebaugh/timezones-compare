# Be sure to restart your server when you modify this file.

# Scripts run only from this site, and the importmap's inline tags carry a
# nonce, so injected markup can't run script even if it slipped past escaping.
# Styles allow inline because the grid colors its cells with style attributes.
# Images may come from any https host: Slack serves avatars from several.
# See https://guides.rubyonrails.org/security.html#content-security-policy-header
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    # Cloudflare Web Analytics' beacon, when CLOUDFLARE_WEB_ANALYTICS_TOKEN is set.
    policy.script_src :self, "https://static.cloudflareinsights.com"
    policy.style_src :self, :unsafe_inline
    policy.img_src :self, :https, :data
    policy.font_src :self, :data
    policy.connect_src :self, "https://cloudflareinsights.com" # the beacon's reports
    policy.object_src :none
    policy.base_uri :self
    # "Sign in with Slack" posts here, then redirects to Slack.
    policy.form_action :self, "https://slack.com", "https://*.slack.com"
    policy.frame_ancestors :none
  end

  # Fresh for every response. (Not the session id: a first-time visitor has
  # none yet, and an empty nonce would block the importmap.)
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
