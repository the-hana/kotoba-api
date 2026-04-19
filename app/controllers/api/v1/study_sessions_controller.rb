module Api
  module V1
    class StudySessionsController < ApplicationController
      # GET /api/v1/study_session
      def show
        session = StudySession.includes(word_day: :word).find_by(user: current_user)
        render json: { success: true, data: serialize(session), error: nil }
      end

      # PUT /api/v1/study_session
      def update
        word_day = WordDay.includes(:word).find(study_session_params[:word_day_id])

        session = current_user.study_session || current_user.build_study_session
        session.word_day = word_day

        if session.save
          render json: { success: true, data: serialize(session), error: nil }
        else
          render json: { success: false, data: nil, error: session.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, data: nil, error: "WordDayが見つかりません" }, status: :not_found
      end

      private

      def study_session_params
        params.permit(:word_day_id)
      end

      def serialize(session)
        return nil if session.nil?

        {
          word_day_id: session.word_day_id,
          jlpt_level: session.word_day.word.jlpt_level,
          day_number: session.word_day.day_number,
          updated_at: session.updated_at
        }
      end
    end
  end
end
