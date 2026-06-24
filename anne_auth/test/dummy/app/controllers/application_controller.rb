class ApplicationController < ActionController::Base
  include Authentication
  include CustomerAuthentication
end
