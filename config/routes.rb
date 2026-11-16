Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  # Browsers and link previewers ask for these by convention.
  get "favicon.ico", to: redirect("/icon.png")

  root "home#show"
  get "privacy" => "pages#privacy", as: :privacy
  get "support" => "pages#support", as: :support
  get "security" => "pages#security", as: :security
  get "terms" => "pages#terms", as: :terms
  get "changelog" => "pages#changelog", as: :changelog
  get "preview" => "previews#show", as: :home_preview
  patch "locale" => "locales#update", as: :locale
  post "client_errors" => "client_errors#create", as: :client_errors

  post "auth/slack" => "sessions#start", as: :slack_sign_in
  get "auth/slack/callback" => "sessions#callback", as: :slack_callback
  post "auth/demo" => "sessions#demo", as: :demo_sign_in
  delete "session" => "sessions#destroy", as: :sign_out
  delete "session/all" => "sessions#destroy_all", as: :sign_out_all
  post "session/switch" => "sessions#switch", as: :switch_account

  resource :setup, only: %i[show create]
  resources :boards, only: :show
  resource :people_picker, only: :show
  resource :people_search, only: :show

  # A shared moment: one hour across a set of time zones.
  get "t/:at" => "moments#show", as: :moment, constraints: { at: /\d{1,12}/ }
end
