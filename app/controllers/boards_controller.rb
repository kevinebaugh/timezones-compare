class BoardsController < ApplicationController
  include GridParams

  MAX_GUESTS = 50

  def show
    @board = Board.find_for(Current.user, params[:id], picked: params[:p]) or raise ActiveRecord::RecordNotFound
    @board.channel&.ensure_members!(token_user: Current.user)
    BoardVisit.record!(Current.user, @board.key) if (@board.group || @board.channel) && @board.member?
    @boards = Board.all_for(Current.user)
    @others = Board.others_for(Current.user, tabs: @boards)
    @members = @board.members.alphabetical.to_a
    @grid = Grid.new(members: @members, reference_tz: grid_tz(Current.user.tz), date: grid_date)
    compare_with_shared_link
    @guests = calendar_guests
    @pin_at = params[:pin].to_i if params[:pin].to_s.match?(/\A\d{1,12}\z/)
    @pin_minutes = meeting_minutes
    refresh_from_slack
  end

  private
    # Opened from a shared link (?shared_z=&shared_at=): which time zones the
    # board has gained or lost since the link was made. "As shared"
    # (?view=shared) shows the link's zones instead, without names, as anyone
    # opening the link signed out would see them.
    def compare_with_shared_link
      return unless (@shared_at = shared_at(params[:shared_at])) && (shared = zone_list(params[:shared_z])).any?

      now = @grid.rows.map { it.zone.identifier }
      @zone_names = zone_names(shared)
      # One entry per name: Brussels and Belgrade are both "Central European
      # Time", and a zone swapped for a same-named one isn't news.
      added, gone = [ now - shared, shared - now ].map { |ids| ids.uniq { @zone_names[it] } }
      same = added.map { @zone_names[it] } & gone.map { @zone_names[it] }
      @zones_added, @zones_gone = [ added, gone ].map { |ids| ids.reject { same.include?(@zone_names[it]) } }
      return @shared_at = nil if @zones_added.empty? && @zones_gone.empty?

      @as_shared = params[:view] == "shared"
      return unless @as_shared

      rows = shared.map { Member.new(name: it, slack_user_id: it, tz: it, tz_label: @zone_names[it]) }
      @grid = Grid.new(members: rows, reference_tz: @grid.reference_zone.identifier, date: @grid.date)
    end

    # What to call each zone: the board's own row name where it has one, else
    # Slack's label from anyone in the workspace in that zone ("Gulf Time"),
    # else the abbreviation.
    def zone_names(shared)
      names = @grid.rows.to_h { [ it.zone.identifier, it.name ] }
      labels = Current.user.workspace.members.people.where.not(tz_label: [ nil, "" ]).where(tz: shared - names.keys)
                      .group(:tz).pluck(:tz, Arel.sql("MAX(tz_label)")).to_h
      (shared | names.keys).to_h { |id| [ id, names[id] || Grid.generic_zone_name(labels[id]) || Member.new(tz: id).zone_name ] }
    end

    # Everyone on the board except me, as calendar guests. Big boards (like the
    # whole workspace) get none, so one click never invites the company.
    def calendar_guests
      emails = @members.reject { it == Current.user.member }.filter_map(&:email)
      emails.size <= MAX_GUESTS ? emails : []
    end

    def refresh_from_slack
      Current.user.workspace.refresh_if_stale!
      Current.user.refresh_my_channels_if_stale!
    end
end
