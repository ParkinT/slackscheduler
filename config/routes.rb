Rails.application.routes.draw do

  root to: 'scheduler#index'
  post 'schedule' => "scheduler#index"
end
