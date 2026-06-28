class Webhooks::DailyStoriesController < Webhooks::ApplicationController
  def create
    words   = DailyWordSelectorService.call
    result  = GeminiService.call(words)

    service_params = {
      story_date:     Date.current.to_s,
      content:        result[:story],
      content_korean: result[:story_korean],
      words:          result[:words]
    }

    story, created = DailyStoryCreationService.call(service_params)

    if created
      Rails.logger.info("[Webhooks] DailyStory 作成完了: story_date=#{story.story_date}")
      render json: { success: true, data: { story_date: story.story_date }, error: nil }, status: :created
    else
      Rails.logger.info("[Webhooks] DailyStory 既存: story_date=#{story.story_date}")
      render json: { success: true, data: { story_date: story.story_date }, error: nil }, status: :ok
    end
  rescue StandardError => e
    Rails.logger.error("[Webhooks] エラー: class=#{e.class} message=#{e.message}\n#{e.backtrace.first(5).join("\n")}")
    render json: { success: false, data: nil, error: "内部エラー / Internal server error" }, status: :internal_server_error
  end
end
