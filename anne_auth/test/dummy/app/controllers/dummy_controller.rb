class DummyController < ApplicationController
  before_action :require_verified_account, only: :verified

  def show
    render plain: "OK"
  end

  def verified
    render plain: "VERIFIED"
  end
end
