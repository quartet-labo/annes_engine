module Authentication
  extend ActiveSupport::Concern

  include AnneAuth::AdminAuthentication
end
