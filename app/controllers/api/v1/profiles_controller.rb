module Api
  module V1
    class ProfilesController < ApplicationController
      # GET /api/v1/profile
      def show
        render json: { success: true, data: profile_data(current_user) }
      end

      # PUT /api/v1/profile
      def update
        if current_user.update(profile_params)
          render json: { success: true, data: profile_data(current_user) }
        else
          render json: { success: false, error: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/profile/password
      def password
        unless current_user.authenticate(password_params[:current_password])
          return render json: { success: false, error: "現在のパスワードが正しくありません" }, status: :unprocessable_entity
        end

        if current_user.update(password: password_params[:new_password])
          render json: { success: true, data: nil }
        else
          render json: { success: false, error: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/profile
      def destroy
        # refresh tokenを無効化してからアカウントを削除
        current_user.update_columns(refresh_token: nil, refresh_token_expires_at: nil)
        current_user.destroy
        render json: { success: true, data: nil }
      end

      private

      def profile_params
        params.permit(:nickname, :target_level)
      end

      def password_params
        params.permit(:current_password, :new_password)
      end

      def profile_data(user)
        {
          id: user.id,
          email: user.email,
          nickname: user.nickname,
          target_level: user.target_level,
          created_at: user.created_at
        }
      end
    end
  end
end
