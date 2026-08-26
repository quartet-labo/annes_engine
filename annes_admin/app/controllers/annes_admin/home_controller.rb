module AnnesAdmin
  class HomeController < ApplicationController
    def show
      @resources = AnnesAdmin.configuration.resources.to_a
    end
  end
end
