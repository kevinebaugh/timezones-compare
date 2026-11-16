# The home page's live sample board: the real board, for a made-up team,
# redrawn for the visitor's time zone. Its links (days, dates, zones) stay
# inside the preview frame.
class PreviewsController < ApplicationController
  include GridParams

  skip_before_action :require_user

  def show
    render partial: "home/preview", locals: { grid: HomePreview.grid(grid_tz(HomePreview::DEFAULT_TZ), date: grid_date) }
  end
end
