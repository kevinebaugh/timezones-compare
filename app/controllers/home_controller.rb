class HomeController < ApplicationController
  skip_before_action :require_user

  def show
    redirect_to board_path(Board::EVERYONE) if signed_in?
  end
end
