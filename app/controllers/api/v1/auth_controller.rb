module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[signup login refresh]

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
        user = User.find_by(email: login_params[:email]&.downcase)
        if user&.authenticate(login_params[:password])
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

      def login_params
        params.permit(:email, :password)
      end

      def refresh_params
        params.permit(:refresh_token, :user_id)
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
        raw_token = refresh_params[:refresh_token]
        raise JWT::DecodeError, "refresh_tokenがありません" if raw_token.blank?

        user = find_user_for_refresh
        raise JWT::DecodeError, "ユーザーが見つかりません" unless user
        raise JWT::DecodeError, "refresh_tokenが無効または期限切れです" unless user.refresh_token_expires_at&.future?
        raise JWT::DecodeError, "refresh_tokenが無効または期限切れです" unless BCrypt::Password.new(user.refresh_token).is_password?(raw_token)

        user
      end

      def find_user_for_refresh
        header = request.headers["Authorization"]
        if header.present?
          # Authorizationヘッダーがある場合: access tokenからuser_idを取得（有効期限切れでも許可）
          token = header.split(" ").last
          decoded = JWT.decode(token, JsonWebToken::SECRET_KEY, false).first
          User.find_by(id: decoded["user_id"])
        else
          # ヘッダーがない場合（ページリロード後など）: bodyのuser_idを使用
          user_id = refresh_params[:user_id]
          raise JWT::DecodeError, "ユーザー情報がありません" if user_id.blank?
          User.find_by(id: user_id)
        end
      end
    end
  end
end
