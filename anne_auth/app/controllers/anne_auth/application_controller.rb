module AnneAuth
  class ApplicationController < ::ApplicationController
    include RouteResolution
    include Authentication
    include AccountAuthentication
  end
end
