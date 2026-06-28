require "net/http"
require "json"

class GeminiService
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

  def self.call(words)
    new(words).call
  end

  def initialize(words)
    @words = words
    @api_key = ENV.fetch("GEMINI_API_KEY")
  end

  def call
    raw = request_gemini
    parse_response(raw)
  end

  private

  def request_gemini
    uri = URI("#{API_URL}?key=#{@api_key}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 55

    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req.body = build_payload.to_json

    res = http.request(req)
    raise "Gemini API error: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  end

  def build_payload
    word_list = @words.each_with_index.map do |w, i|
      "#{i + 1}. #{w.japanese}（#{w.hiragana}）: #{w.korean}"
    end.join("\n")

    {
      contents: [ {
        parts: [ {
          text: <<~PROMPT
            あなたはJLPT日本語学習アプリのAIアシスタントです。
            韓国語を母国語とする日本語学習者向けに、以下の単語をすべて使った短いストーリーと各単語の例文を作成してください。

            単語リスト（番号順）:
            #{word_list}

            以下のJSON形式のみで出力してください。余分なテキストは不要です:
            {
              "story": "全単語を自然に盛り込んだ日本語ストーリー（200〜300文字）",
              "story_korean": "ストーリーの韓国語翻訳",
              "examples": [
                { "example_sentence": "単語1を使った自然な日本語例文", "example_sentence_korean": "例文の韓国語翻訳" },
                { "example_sentence": "単語2を使った自然な日本語例文", "example_sentence_korean": "例文の韓国語翻訳" }
              ]
            }

            examples は単語リストと同じ順番で#{@words.size}個作成してください。
          PROMPT
        } ]
      } ],
      generationConfig: {
        responseMimeType: "application/json"
      }
    }
  end

  def parse_response(raw)
    text = raw.dig("candidates", 0, "content", "parts", 0, "text")
    raise "Gemini レスポンスが空です" if text.blank?

    data = JSON.parse(text)

    words_result = @words.each_with_index.map do |word, i|
      ex = data["examples"][i] || {}
      {
        word_id:                 word.id,
        example_sentence:        ex["example_sentence"].to_s,
        example_sentence_korean: ex["example_sentence_korean"].to_s
      }
    end

    {
      story:        data["story"].to_s,
      story_korean: data["story_korean"].to_s,
      words:        words_result
    }
  end
end
