class User < ApplicationRecord
  has_secure_password

  has_many :word_bookmarks, dependent: :destroy
  has_many :bookmarked_words, through: :word_bookmarks, source: :word
  has_one :study_session, dependent: :destroy

  JLPT_LEVELS = %w[n5 n4 n3 n2 n1].freeze

  before_save :downcase_email

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :nickname, presence: true, length: { maximum: 30 }
  validates :target_level, inclusion: { in: JLPT_LEVELS }

  private

  def downcase_email
    self.email = email.downcase
  end
end
