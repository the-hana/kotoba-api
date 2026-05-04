require "rails_helper"

RSpec.describe "Api::V1::Profiles", type: :request do
  describe "GET /api/v1/profile" do
    context "正常系: 認証済みユーザー" do
      let(:user) { create(:user) }

      before { get "/api/v1/profile", headers: auth_headers(user) }

      it "200を返しユーザー情報を含む" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        data = response.parsed_body["data"]
        expect(data["id"]).to eq user.id
        expect(data["email"]).to eq user.email
        expect(data["nickname"]).to eq user.nickname
        expect(data["target_level"]).to eq user.target_level
        expect(data["created_at"]).to be_present
      end
    end

    context "異常系: Authorizationヘッダーなし" do
      before { get "/api/v1/profile" }

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end

  describe "PUT /api/v1/profile" do
    context "正常系: nicknameを更新" do
      let(:user) { create(:user, nickname: "旧ニックネーム") }

      before { put "/api/v1/profile", params: { nickname: "新ニックネーム" }, headers: auth_headers(user) }

      it "200を返しnicknameが更新される" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(user.reload.nickname).to eq "新ニックネーム"
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["data"]["nickname"]).to eq "新ニックネーム"
      end
    end

    context "正常系: target_levelを更新" do
      let(:user) { create(:user, target_level: "n5") }

      before { put "/api/v1/profile", params: { target_level: "n2" }, headers: auth_headers(user) }

      it "200を返しtarget_levelが更新される" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(user.reload.target_level).to eq "n2"
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["data"]["target_level"]).to eq "n2"
      end
    end

    context "異常系: nicknameが空文字" do
      let(:user) { create(:user) }

      before { put "/api/v1/profile", params: { nickname: "" }, headers: auth_headers(user) }

      it "422を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 422
        # 2. DBのアサーション
        expect(user.reload.nickname).not_to eq ""
        # 3. 構造のアサーション
        assert_response_schema_confirm(422)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "異常系: 不正なtarget_level" do
      let(:user) { create(:user) }

      before { put "/api/v1/profile", params: { target_level: "n9" }, headers: auth_headers(user) }

      it "422を返す" do
        expect(response.status).to eq 422
        assert_response_schema_confirm(422)
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "異常系: Authorizationヘッダーなし" do
      before { put "/api/v1/profile", params: { nickname: "test" } }

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end

  describe "PUT /api/v1/profile/password" do
    context "正常系: 正しい現在のパスワードで変更成功" do
      before do
        user = create(:user, password: "oldpassword", password_confirmation: "oldpassword")
        put "/api/v1/profile/password",
          params: { current_password: "oldpassword", new_password: "newpassword" },
          headers: auth_headers(user)
      end

      it "200を返し新しいパスワードで認証できる" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(User.first.authenticate("newpassword")).to be_truthy
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["data"]).to be_nil
      end
    end

    context "異常系: 現在のパスワードが不正" do
      before do
        user = create(:user, password: "correctpassword", password_confirmation: "correctpassword")
        put "/api/v1/profile/password",
          params: { current_password: "wrongpassword", new_password: "newpassword" },
          headers: auth_headers(user)
      end

      it "422を返しパスワードは変更されない" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 422
        # 2. DBのアサーション
        expect(User.first.authenticate("newpassword")).to be false
        # 3. 構造のアサーション
        assert_response_schema_confirm(422)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "異常系: 新しいパスワードが6文字未満" do
      before do
        user = create(:user, password: "oldpassword", password_confirmation: "oldpassword")
        put "/api/v1/profile/password",
          params: { current_password: "oldpassword", new_password: "abc" },
          headers: auth_headers(user)
      end

      it "422を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 422
        # 2. DBのアサーション
        expect(User.first.authenticate("abc")).to be false
        # 3. 構造のアサーション
        assert_response_schema_confirm(422)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "異常系: new_passwordが空" do
      before do
        user = create(:user, password: "oldpassword", password_confirmation: "oldpassword")
        put "/api/v1/profile/password",
          params: { current_password: "oldpassword" },
          headers: auth_headers(user)
      end

      it "422を返し日本語エラーメッセージを含む" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 422
        # 2. DBのアサーション
        expect(User.first.authenticate("oldpassword")).to be_truthy
        # 3. 構造のアサーション
        assert_response_schema_confirm(422)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to eq "新しいパスワードを入力してください"
      end
    end

    context "異常系: Authorizationヘッダーなし" do
      before do
        put "/api/v1/profile/password",
          params: { current_password: "oldpassword", new_password: "newpassword" }
      end

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end

  describe "DELETE /api/v1/profile" do
    context "正常系: 退会成功" do
      before do
        user = create(:user)
        create(:word_bookmark, user: user)
        create(:study_session, user: user)
        delete "/api/v1/profile", headers: auth_headers(user)
      end

      it "200を返しユーザーと関連データが削除される" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(User.count).to eq 0
        expect(WordBookmark.count).to eq 0
        expect(StudySession.count).to eq 0
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["data"]).to be_nil
      end
    end

    context "異常系: Authorizationヘッダーなし" do
      before { delete "/api/v1/profile" }

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end
end
