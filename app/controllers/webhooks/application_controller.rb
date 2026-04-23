class Webhooks::ApplicationController < ActionController::API
  before_action :authenticate_internal_request!

  private

  def authenticate_internal_request!
    token = request.headers["X-Internal-Token"]
    expected = ENV.fetch("INTERNAL_API_KEY")

    unless ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected)
      Rails.logger.warn("[Webhooks] 認証失敗 / Auth failed: ip=#{request.remote_ip}")
      render json: { success: false, data: nil, error: "Unauthorized / 認証エラー" }, status: :unauthorized
    end
  rescue KeyError
    Rails.logger.error("[Webhooks] INTERNAL_API_KEY が未設定 / INTERNAL_API_KEY not configured")
    render json: { success: false, data: nil, error: "Server configuration error" }, status: :internal_server_error
  end
end
