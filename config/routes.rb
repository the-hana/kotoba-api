Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      namespace :auth do
        post :signup
        post :login
        post :refresh
        delete :logout
      end
      resources :words, only: %i[index show]
    end
  end
end
