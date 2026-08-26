class DummyController < ApplicationController
  include AnnesAccess::Authorization

  attr_writer :current_account, :current_user

  def show
    head :ok
  end

  private
    attr_reader :current_account, :current_user
end
