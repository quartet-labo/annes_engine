module Staff
  class MembersController < ApplicationController
    before_action :require_account_authentication

    def index
      render plain: "Restaurant loyalty staff members"
    end
  end
end
