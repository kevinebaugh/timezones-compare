# Plain public pages: the privacy policy and support.
class PagesController < ApplicationController
  skip_before_action :require_user

  def privacy; end
  def support; end
  def security; end
  def terms; end

  def changelog
    @days = Changelog.days
  end
end
