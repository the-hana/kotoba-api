require "rails_helper"

RSpec.describe "Api::V1::Bookmarks", type: :request do
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
