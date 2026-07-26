module Customers
  class DashboardController < ApplicationController
    def show
      render plain: "Restaurant loyalty customer dashboard"
    end
  end
end
