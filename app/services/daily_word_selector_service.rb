class DailyWordSelectorService
  WORDS_PER_STORY = 10

  def self.call
    new.call
  end

  def call
    level   = most_popular_target_level
    unused  = unused_words(level)

    return unused if unused.size == WORDS_PER_STORY

    # 未使用が不足する場合、使用済み単語で補充（重複許可）
    used = used_words(level, WORDS_PER_STORY - unused.size)
    unused + used
  end

  private

  def most_popular_target_level
    User.group(:target_level).count.max_by { |_, c| c }&.first || "n5"
  end

  def unused_words(level)
    Word.where(jlpt_level: level)
        .where.not(id: DailyStoryWord.select(:word_id))
        .order("RANDOM()")
        .limit(WORDS_PER_STORY)
        .to_a
  end

  def used_words(level, count)
    Word.where(jlpt_level: level)
        .where(id: DailyStoryWord.select(:word_id))
        .order("RANDOM()")
        .limit(count)
        .to_a
  end
end
