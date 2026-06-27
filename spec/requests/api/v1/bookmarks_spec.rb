require "rails_helper"

RSpec.describe "Api::V1::Bookmarks", type: :request do
  describe "GET /api/v1/bookmarks" do
    context "正常系: 全ブックマーク一覧（jlpt_level未指定）" do
      let(:user) { create(:user) }
      let(:word1) { create(:word, jlpt_level: "n5") }
      let(:word2) { create(:word, jlpt_level: "n4") }

      before do
        create(:word_bookmark, user: user, word: word1)
        create(:word_bookmark, user: user, word: word2)
        get "/api/v1/bookmarks", headers: auth_headers(user)
      end

      it "200を返し全ブックマーク済み単語を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["data"].map { |w| w["id"] }).to contain_exactly(word1.id, word2.id)
        expect(response.parsed_body["data"].all? { |w| w["bookmarked"] == true }).to be true
      end
    end

    context "正常系: jlpt_levelフィルタリング" do
      let(:user) { create(:user) }
      let(:word_n5) { create(:word, jlpt_level: "n5") }
      let(:word_n4) { create(:word, jlpt_level: "n4") }

      before do
        create(:word_bookmark, user: user, word: word_n5)
        create(:word_bookmark, user: user, word: word_n4)
        get "/api/v1/bookmarks", params: { jlpt_level: "n5" }, headers: auth_headers(user)
      end

      it "200を返しn5の単語のみ返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["data"].length).to eq 1
        expect(response.parsed_body["data"].first["id"]).to eq word_n5.id
        expect(response.parsed_body["data"].first["jlpt_level"]).to eq "n5"
      end
    end

    context "正常系: ブックマークなし → 空配列" do
      let(:user) { create(:user) }

      before { get "/api/v1/bookmarks", headers: auth_headers(user) }

      it "200を返し空配列を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["data"]).to eq []
      end
    end

    context "異常系: 不正なjlpt_level" do
      let(:user) { create(:user) }

      before { get "/api/v1/bookmarks", params: { jlpt_level: "invalid" }, headers: auth_headers(user) }

      it "400を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 400
        # 3. 構造のアサーション
        assert_response_schema_confirm(400)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "異常系: Authorizationヘッダーなし" do
      before { get "/api/v1/bookmarks" }

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end

  describe "POST /api/v1/words/:word_id/bookmark" do
    context "正常系: ブックマーク追加" do
      let(:user) { create(:user) }
      let(:word) { create(:word) }

      before { post "/api/v1/words/#{word.id}/bookmark", headers: auth_headers(user) }

      it "201を返しDBにレコードが作成される" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 201
        # 2. DBのアサーション
        expect(WordBookmark.exists?(user: user, word: word)).to be true
        # 3. 構造のアサーション
        assert_response_schema_confirm(201)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
      end
    end

    context "異常系: すでにブックマーク済み" do
      let(:user) { create(:user) }
      let(:word) { create(:word) }

      before do
        create(:word_bookmark, user: user, word: word)
        post "/api/v1/words/#{word.id}/bookmark", headers: auth_headers(user)
      end

      it "422を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 422
        # 3. 構造のアサーション
        assert_response_schema_confirm(422)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "異常系: 存在しない word_id" do
      let(:user) { create(:user) }

      before { post "/api/v1/words/99999/bookmark", headers: auth_headers(user) }

      it "404を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 404
        # 3. 構造のアサーション
        assert_response_schema_confirm(404)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "異常系: Authorizationヘッダーなし" do
      let(:word) { create(:word) }

      before { post "/api/v1/words/#{word.id}/bookmark" }

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end

  describe "DELETE /api/v1/words/:word_id/bookmark" do
    context "正常系: ブックマーク解除" do
      let(:user) { create(:user) }
      let(:word) { create(:word) }

      before do
        create(:word_bookmark, user: user, word: word)
        delete "/api/v1/words/#{word.id}/bookmark", headers: auth_headers(user)
      end

      it "200を返しDBからレコードが削除される" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(WordBookmark.exists?(user: user, word: word)).to be false
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
      end
    end

    context "異常系: ブックマークが存在しない" do
      let(:user) { create(:user) }
      let(:word) { create(:word) }

      before { delete "/api/v1/words/#{word.id}/bookmark", headers: auth_headers(user) }

      it "404を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 404
        # 3. 構造のアサーション
        assert_response_schema_confirm(404)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "異常系: 他ユーザーのブックマークを削除しようとした場合" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }
      let(:word) { create(:word) }

      before do
        create(:word_bookmark, user: other_user, word: word)
        delete "/api/v1/words/#{word.id}/bookmark", headers: auth_headers(user)
      end

      it "404を返す（自分のブックマークにないため）" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 404
        # 2. DBのアサーション（他ユーザーのブックマークは消えていない）
        expect(WordBookmark.exists?(user: other_user, word: word)).to be true
        # 3. 構造のアサーション
        assert_response_schema_confirm(404)
      end
    end

    context "異常系: Authorizationヘッダーなし" do
      let(:word) { create(:word) }

      before { delete "/api/v1/words/#{word.id}/bookmark" }

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end
end
