Rails.application.routes.draw do
  match "/preview/:id", to: "preview#show", via: [ :get, :post ]
  mount AnnesInquiry::Engine => "/inquiry"
end
