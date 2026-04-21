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

  def call
    raise ArgumentError, "単語は#{REQUIRED_WORDS_COUNT}個必要です" unless @word_data.size == REQUIRED_WORDS_COUNT

    ActiveRecord::Base.transaction do
      story = DailyStory.create!(
        story_date:     @story_date,
        content:        @content,
        content_korean: @content_korean
      )

      @word_data.each do |wd|
        DailyStoryWord.create!(daily_story: story, word_id: wd[:word_id])
        AiContent.create!(
          daily_story:             story,
          word_id:                 wd[:word_id],
          example_sentence:        wd[:example_sentence],
          example_sentence_korean: wd[:example_sentence_korean]
        )
      end

      story
    end
  end
end
