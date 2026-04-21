module Api
  module V1
    class DailyStoriesController < ApplicationController
      # GET /api/v1/daily_story
      def show
        story = DailyStory.includes(:words, :ai_contents)
                          .order(story_date: :desc)
                          .first

        if story
          render json: { success: true, data: serialize(story), error: nil }
        else
          render json: { success: false, data: nil, error: "ストーリーがまだ生成されていません" },
                 status: :not_found
        end
      end

      private

      def serialize(story)
        ai_map = story.ai_contents.index_by(&:word_id)

        {
          story_date:     story.story_date,
          content:        story.content,
          content_korean: story.content_korean,
          words: story.words.map { |w|
            ac = ai_map[w.id]
            {
              id:                      w.id,
              japanese:                w.japanese,
              hiragana:                w.hiragana,
              korean:                  w.korean,
              jlpt_level:              w.jlpt_level,
              example_sentence:        ac&.example_sentence,
              example_sentence_korean: ac&.example_sentence_korean
            }
          }
        }
      end
    end
  end
end
