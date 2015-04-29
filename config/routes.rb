Rails.application.routes.draw do
  get 'envstat/index'

  # Root path
  root 'envstat#index'

  # Route /envstat/* incoming Rails requests to envstat_controller index method
  #get '*path' => 'envstat#index'
  get '/envstat' => 'envstat#index'


  #
  # Routes for angular to rest/json api
  # Accessed at http://http://localhost:3000/api/v1/<method>
  namespace :api do
    namespace :v1 do
      get 'envsStatus' => 'aws#envsStatus'
      get 'shardStatus' => 'aws#shardStatus'
      get 'flushCaches' => 'aws#flushCaches'
      get 'startEnv' => 'aws#startEnv'
      get 'stopEnv' => 'aws#stopEnv'
      get 'regions' => 'aws#regions'
    end
  end
end
