module ApplicationHelper
  # Absolute URL on the public host (APP_URL, e.g. https://timezones.compare),
  # falling back to the host that served the request. Link previews need these.
  def site_url(path = "/")
    base = ENV["APP_URL"].presence || request.base_url
    URI.join(base.chomp("/") + "/", path.delete_prefix("/")).to_s
  end

  # Where people write for help or to have their data deleted.
  # "Built by Kevin Ebaugh.", plus "Tested at <company>." when a deployment sets
  # FOOTER_COMPANY_NAME (and optionally FOOTER_COMPANY_URL). Off-site links
  # open in a new tab, so the board you're on stays open.
  def footer_credit
    author = link_to("Kevin Ebaugh", "https://kevinebaugh.com", class: "footer-link", rel: "author noopener", target: "_blank")
    return t("site.built_by_only_html", author:) unless (name = ENV["FOOTER_COMPANY_NAME"].presence)

    url = ENV["FOOTER_COMPANY_URL"].presence
    company = url ? link_to(name, url, class: "footer-link", rel: "noopener", target: "_blank") : name
    t("site.built_by_html", author:, company:)
  end

  def support_email
    ENV["SUPPORT_EMAIL"].presence || "help@timezones.compare"
  end
end
