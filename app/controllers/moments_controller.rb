# A shared link to one time slot across a set of time zones (from "Copy link"):
# /t/<start>?d=<minutes>, at quarter-hour precision.
#
# Teammates who can see the board it came from land on that board with the
# hour pinned. Anyone else sees the same time zones with the hour pinned, but
# no names or working hours: the link only reveals which zones a team spans.
class MomentsController < ApplicationController
  include GridParams

  skip_before_action :require_user

  def show
    @at = Time.at(params[:at].to_i).utc
    @minutes = meeting_minutes
    zones = zone_list(params[:z])
    @shared_at = shared_at(params[:g])
    raise ActiveRecord::RecordNotFound if zones.empty? || !@at.between?(5.years.ago, 5.years.from_now)

    reference = grid_tz(zones.first)
    date = TZInfo::Timezone.get(reference).to_local(@at).to_date

    if signed_in? && (board = Board.find_for(Current.user, params[:b].to_s))
      # The zones as shared ride along, so the board can say if they've changed since.
      snapshot = { shared_z: zones.join(","), shared_at: @shared_at.to_i } if @shared_at
      return redirect_to board_path(board, date: date.iso8601, tz: reference, pin: @at.to_i, d: @minutes, **board.query, **snapshot.to_h)
    end

    session[:return_to] = request.fullpath unless signed_in?
    @zones = zones
    @grid = Grid.new(members: zones.map { Member.new(name: it, slack_user_id: it, tz: it) }, reference_tz: reference, date:)
    clock = helpers.clock_preference == "12" ? :clock_12 : :clock_24
    local = @grid.reference_zone.to_local(@at)
    time = I18n.l(local, format: clock)
    time = "#{time}–#{I18n.l(@grid.reference_zone.to_local(@at + @minutes.minutes), format: clock)}" if @minutes
    @heading = I18n.t("grid.moment_heading", date: I18n.l(local.to_date, format: :weekday_short), time:, zone: @grid.reference_name)
    @description = @grid.rows.map do |row|
      there = row.zone.to_local(@at)
      day = I18n.l(there.to_date, format: "%a") unless there.to_date == local.to_date
      weekend = "(#{I18n.t("grid.weekend")})" if Grid.weekend_days(row.zone).include?(there.wday)
      [ day, I18n.l(there, format: :clock_12), row.name, weekend ].compact.join(" ")
    end.join(" · ")
  end
end
