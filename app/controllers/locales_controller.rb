# The footer's language picker: remember the choice, then go back.
class LocalesController < ApplicationController
  skip_before_action :require_user

  def update
    code = params[:locale].to_s
    if Languages.supported?(code)
      cookies.permanent[:locale] = { value: code, same_site: :lax }
    end
    back = URI(request.referer.to_s).request_uri rescue nil
    redirect_to(back&.start_with?("/") && !back.start_with?("//") ? back : root_path)
  end
end
