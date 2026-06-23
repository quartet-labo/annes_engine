module AnneAuth
  class ApplicationController < ::ApplicationController
    include RouteResolution
    include AccountAuthentication
  end
end
