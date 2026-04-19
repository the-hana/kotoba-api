module Api
  module V1
    class BookmarksController < ApplicationController
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
    end
  end
end
