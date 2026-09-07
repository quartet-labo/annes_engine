class PreviewController < ActionController::Base
  helper AnnesInquiry::FormHelper

  def show
    @version = AnnesInquiry::FormVersion.find(params[:id])
    raw = params[:inquiry].is_a?(ActionController::Parameters) ? params[:inquiry].to_unsafe_h : (params[:inquiry] || {})
    @input = AnnesInquiry::Input.new(@version, raw_values: raw, time_zone: "Asia/Tokyo")
    status = request.post? && !@input.valid? ? :unprocessable_entity : :ok
    render :show, status: status
  end
end
