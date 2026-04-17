class ApplicationController < ActionController::API
  include JsonWebToken

  before_action :authenticate_user!

  private

  def authenticate_user!
    token = extract_token_from_header
    decoded = JsonWebToken.decode(token)
    @current_user = User.find(decoded[:user_id])
  rescue JWT::ExpiredSignature, JWT::DecodeError => e
    render json: { success: false, error: e.message }, status: :unauthorized
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "ユーザーが見つかりません" }, status: :unauthorized
  end

  def current_user
    @current_user
  end

  def extract_token_from_header
    header = request.headers["Authorization"]
    raise JWT::DecodeError, "Authorizationヘッダーがありません" if header.blank?

    # Bearer <token> 形式を想定
    header.split(" ").last
  end
end
