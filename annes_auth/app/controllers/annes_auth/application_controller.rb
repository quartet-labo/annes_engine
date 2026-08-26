module AnnesAuth
  class ApplicationController < ::ApplicationController
    include RouteResolution
    include AccountAuthentication
  end
end
