Rails.application.routes.draw do
  mount AnnesIntake::Engine => "/intake"
  mount AnnesInquiry::Engine => "/inquiry"
  get "/copy_question/:id", to: "question_bridge#new"
  post "/copy_question/:id", to: "question_bridge#create"
end
