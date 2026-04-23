class Webhooks::DailyStoriesController < Webhooks::ApplicationController
  def create
    story, created = DailyStoryCreationService.call(creation_params)

    if created
      Rails.logger.info("[Webhooks] DailyStory 作成完了 / Created: story_date=#{story.story_date}")
      render json: { success: true, data: { story_date: story.story_date }, error: nil }, status: :created
    else
      Rails.logger.info("[Webhooks] DailyStory 既存 / Already exists: story_date=#{story.story_date}")
      render json: { success: true, data: { story_date: story.story_date }, error: nil }, status: :ok
    end
  rescue ArgumentError => e
    Rails.logger.warn("[Webhooks] バリデーションエラー / Validation error: story_date=#{params[:story_date]} error=#{e.message}")
    render json: { success: false, data: nil, error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("[Webhooks] 予期しないエラー / Unexpected error: story_date=#{params[:story_date]} class=#{e.class} message=#{e.message}\n#{e.backtrace.first(5).join("\n")}")
    render json: { success: false, data: nil, error: "内部エラー / Internal server error" }, status: :internal_server_error
  end

  private

  def creation_params
    params.permit(:story_date, :content, :content_korean, words: [ :word_id, :example_sentence, :example_sentence_korean ])
          .to_h.deep_symbolize_keys
  end
end
