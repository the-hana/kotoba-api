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
      resources :bookmarks, only: %i[index]
      resources :word_days, only: %i[index]
      resources :words, only: %i[index show] do
        resource :bookmark, only: %i[create destroy]
      end
      resource :study_session, only: %i[show update]
      resource :profile, only: %i[show update destroy]
      resource :daily_story, only: %i[show], controller: "daily_stories"
    end
  end
end
