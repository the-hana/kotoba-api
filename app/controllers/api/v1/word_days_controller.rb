module Api
  module V1
    class WordDaysController < ApplicationController
      # GET /api/v1/word_days?jlpt_level=n5
      def index
        unless Word::JLPT_LEVELS.include?(params[:jlpt_level])
          return render json: { success: false, data: nil, error: "jlpt_levelは必須です（n5/n4/n3/n2/n1）" }, status: :bad_request
        end

        # レベルに属するword_daysをday_number順に取得し、DAYごとに先頭1件を代表として返す
        word_days = WordDay
          .joins(:word)
          .where(words: { jlpt_level: params[:jlpt_level] })
          .select("MIN(word_days.id) AS id, word_days.day_number")
          .group(:day_number)
          .order(:day_number)

        data = word_days.map { |wd| { id: wd.id, day_number: wd.day_number } }
        render json: { success: true, data: data, error: nil }
      end
    end
  end
end
