module Customers
  class SessionsController < ApplicationController
    rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to customer_login_path, alert: "時間をおいて再度お試しください。" }

    def new
    end

    def create
      customer = Customer.active.find_by(customer_number: customer_number)

      if customer&.authenticate_access_code(access_code)
        reset_session
        session[:customer_id] = customer.id
        redirect_to customer_root_path, notice: "ログインしました。"
      else
        flash.now[:alert] = "会員番号またはアクセスコードが正しくありません。"
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      session.delete(:customer_id)
      redirect_to customer_login_path, notice: "ログアウトしました。"
    end

    private
      def customer_number
        params[:customer_number].to_s.strip.upcase
      end

      def access_code
        params[:access_code].to_s
      end
  end
end
