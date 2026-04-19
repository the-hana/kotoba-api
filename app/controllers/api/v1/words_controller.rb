module Api
  module V1
    class WordsController < ApplicationController
      # GET /api/v1/words?jlpt_level=n5&day_number=1
      def index
        unless Word::JLPT_LEVELS.include?(params[:jlpt_level])
          return render json: { success: false, data: nil, error: "jlpt_levelは必須です（n5/n4/n3/n2/n1）" }, status: :bad_request
        end

        words = Word.where(jlpt_level: params[:jlpt_level])

        if params[:day_number].present?
          words = words.joins(:word_days).where(word_days: { day_number: params[:day_number] })
        end

        bookmarked_ids = current_user.word_bookmarks.where(word_id: words.map(&:id)).pluck(:word_id).to_set

        data = words.map { |w| serialize_word(w, bookmarked_ids.include?(w.id)) }
        render json: { success: true, data: data, error: nil }
      end

      # GET /api/v1/words/:id
      def show
        word = Word.find(params[:id])
        bookmarked = current_user.word_bookmarks.exists?(word_id: word.id)
        ai_content = word.ai_contents.order(created_at: :desc).first

        render json: {
          success: true,
          data: serialize_word(word, bookmarked).merge(ai_content: serialize_ai_content(ai_content)),
          error: nil
        }
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, data: nil, error: "単語が見つかりません" }, status: :not_found
      end

      private

      def serialize_word(word, bookmarked)
        {
          id: word.id,
          japanese: word.japanese,
          hiragana: word.hiragana,
          korean: word.korean,
          jlpt_level: word.jlpt_level,
          bookmarked: bookmarked
        }
      end

      def serialize_ai_content(ai_content)
        return nil unless ai_content

        {
          example_sentence: ai_content.example_sentence,
          example_sentence_korean: ai_content.example_sentence_korean
        }
      end
    end
  end
end
