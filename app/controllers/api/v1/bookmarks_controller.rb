module Api
  module V1
    class BookmarksController < ApplicationController
      # GET /api/v1/bookmarks?jlpt_level=n5
      def index
        # word_bookmarksをJOINして一括取得。serialize_wordでassociationを追加する場合はここにincludesを付ける
        words = current_user.bookmarked_words
        if params[:jlpt_level].present?
          unless Word::JLPT_LEVELS.include?(params[:jlpt_level])
            return render json: { success: false, data: nil, error: "jlpt_levelが不正です（n5/n4/n3/n2/n1）" }, status: :bad_request
          end
          words = words.where(jlpt_level: params[:jlpt_level])
        end
        data = words.map { |w| serialize_word(w) }
        render json: { success: true, data: data, error: nil }
      end

      # POST /api/v1/words/:word_id/bookmark
      def create
        word = Word.find(params[:word_id])
        bookmark = current_user.word_bookmarks.build(word: word)

        if bookmark.save
          render json: { success: true, data: nil, error: nil }, status: :created
        else
          render json: { success: false, data: nil, error: bookmark.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, data: nil, error: "単語が見つかりません" }, status: :not_found
      end

      # DELETE /api/v1/words/:word_id/bookmark
      def destroy
        bookmark = current_user.word_bookmarks.find_by!(word_id: params[:word_id])
        bookmark.destroy!
        render json: { success: true, data: nil, error: nil }
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, data: nil, error: "ブックマークが見つかりません" }, status: :not_found
      end

      private

      def serialize_word(word)
        {
          id: word.id,
          japanese: word.japanese,
          hiragana: word.hiragana,
          korean: word.korean,
          jlpt_level: word.jlpt_level,
          bookmarked: true
        }
      end
    end
  end
end
