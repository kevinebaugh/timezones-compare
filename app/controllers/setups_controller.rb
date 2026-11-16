# The short screen shown the first time anyone from a workspace signs in,
# while the roster and groups load, so the first board is complete.
class SetupsController < ApplicationController
  before_action { @workspace = Current.user.workspace }

  def show
    redirect_to board_path(Board::EVERYONE) unless @workspace.needs_first_sync?
  end

  def create
    @workspace.prepare_first_view! if @workspace.needs_first_sync?
    redirect_to after_sign_in_path, status: :see_other
  end
end
