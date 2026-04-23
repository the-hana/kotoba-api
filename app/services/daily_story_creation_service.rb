class DailyStoryCreationService
  REQUIRED_WORDS_COUNT = 10

  def initialize(params)
    @story_date     = params[:story_date]
    @content        = params[:content]
    @content_korean = params[:content_korean]
    @word_data      = params[:words]
  end

  def self.call(params)
    new(params).call
  end

  # 戻り値: [story, created]
  #   created = true  → 新規作成
  #   created = false → 冪等: すでに存在していた
  def call
    validate_input!

    existing = DailyStory.find_by(story_date: @story_date)
    return [ existing, false ] if existing

    [ create_story!, true ]
  end

  private

  def validate_input!
    raise ArgumentError, "story_date が無効です / Invalid story_date" if @story_date.blank?
    begin
      Date.parse(@story_date.to_s)
    rescue ArgumentError, TypeError
      raise ArgumentError, "story_date が無効です / Invalid story_date"
    end

    unless @word_data&.size == REQUIRED_WORDS_COUNT
      raise ArgumentError, "単語は#{REQUIRED_WORDS_COUNT}個必要です"
    end

    word_ids = @word_data.map { |wd| wd[:word_id] }
    if word_ids.size != word_ids.uniq.size
      raise ArgumentError, "word_id に重複があります / Duplicate word_id"
    end
  end

  def create_story!
    ActiveRecord::Base.transaction do
      story = DailyStory.create!(
        story_date:     @story_date,
        content:        @content,
        content_korean: @content_korean
      )

      now = Time.current

      DailyStoryWord.insert_all!(
        @word_data.map { |wd| { daily_story_id: story.id, word_id: wd[:word_id], created_at: now, updated_at: now } }
      )

      AiContent.insert_all!(
        @word_data.map do |wd|
          {
            daily_story_id:          story.id,
            word_id:                 wd[:word_id],
            example_sentence:        wd[:example_sentence],
            example_sentence_korean: wd[:example_sentence_korean],
            created_at:              now,
            updated_at:              now
          }
        end
      )

      story
    end
  rescue ActiveRecord::InvalidForeignKey
    raise ArgumentError, "存在しない word_id が含まれています / Invalid word_id"
  end
end
