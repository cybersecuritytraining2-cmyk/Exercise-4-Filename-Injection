Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    post "auth/register", to: "auth#register"
    post "auth/login",    to: "auth#login"
    put    "files",       to: "files#create"
    get    "files",       to: "files#index"
    get    "files/:id",   to: "files#show"
    delete "files/:id",   to: "files#destroy"
  end

  get "share/:token", to: "share#download"
end
