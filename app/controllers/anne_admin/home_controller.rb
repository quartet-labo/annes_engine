module AnneAdmin
  class HomeController < ApplicationController
    def show
      @resources = AnneAdmin.configuration.resources.to_a
    end
  end
end
