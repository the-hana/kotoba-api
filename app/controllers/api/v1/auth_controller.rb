module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[signup login]

      # POST /api/v1/auth/signup
      def signup
        user = User.new(signup_params)
        if user.save
          tokens = issue_tokens(user)
          render json: { success: true, data: tokens }, status: :created
        else
          render json: { success: false, error: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/auth/login
      def login
        user = User.find_by(email: params[:email]&.downcase)
        if user&.authenticate(params[:password])
          tokens = issue_tokens(user)
          render json: { success: true, data: tokens }
        else
          render json: { success: false, error: "メールアドレスまたはパスワードが正しくありません" }, status: :unauthorized
        end
      end

      # POST /api/v1/auth/refresh
      def refresh
        user = find_user_by_refresh_token
        tokens = issue_tokens(user)
        render json: { success: true, data: tokens }
      rescue JWT::DecodeError => e
        render json: { success: false, error: e.message }, status: :unauthorized
      end

      # DELETE /api/v1/auth/logout
      def logout
        current_user.update!(refresh_token: nil, refresh_token_expires_at: nil)
        render json: { success: true, data: nil }
      end

      private

      def signup_params
        params.permit(:email, :nickname, :password, :password_confirmation, :target_level)
      end

      def issue_tokens(user)
        raw_refresh_token = SecureRandom.hex(32)
        user.update!(
          refresh_token: BCrypt::Password.create(raw_refresh_token),
          refresh_token_expires_at: JsonWebToken::REFRESH_TOKEN_EXPIRY.from_now
        )

        access_token = JsonWebToken.encode_access_token(user_id: user.id)
        { access_token: access_token, refresh_token: raw_refresh_token }
      end

      def find_user_by_refresh_token
        raw_token = params[:refresh_token]
        raise JWT::DecodeError, "refresh_tokenがありません" if raw_token.blank?

        # Authorizationヘッダーのaccess tokenからuser_idを取得（有効期限切れでも許可）
        header = request.headers["Authorization"]
        raise JWT::DecodeError, "Authorizationヘッダーがありません" if header.blank?

        token = header.split(" ").last
        decoded = JWT.decode(token, JsonWebToken::SECRET_KEY, false).first
        user = User.find_by(id: decoded["user_id"])

        raise JWT::DecodeError, "ユーザーが見つかりません" unless user
        raise JWT::DecodeError, "refresh_tokenが無効または期限切れです" unless user.refresh_token_expires_at&.future?
        raise JWT::DecodeError, "refresh_tokenが無効または期限切れです" unless BCrypt::Password.new(user.refresh_token).is_password?(raw_token)

        user
      end
    end
  end
end
