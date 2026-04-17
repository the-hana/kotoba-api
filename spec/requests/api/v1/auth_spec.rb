require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/signup" do
    context "正常系" do
      before do
        post "/api/v1/auth/signup", params: {
          email: "test@example.com",
          nickname: "テストユーザー",
          password: "password123",
          password_confirmation: "password123",
          target_level: "n5"
        }
      end

      it "ユーザーを作成してトークンを返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 201
        # 2. DBのアサーション
        expect(User.count).to eq 1
        expect(User.last.email).to eq "test@example.com"
        expect(User.last.refresh_token).to be_present
        # 3. 構造のアサーション
        assert_response_schema_confirm(201)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["data"]["access_token"]).to be_present
        expect(response.parsed_body["data"]["refresh_token"]).to be_present
      end
    end

    context "メールアドレス重複の場合" do
      before do
        create(:user, email: "dup@example.com")
        post "/api/v1/auth/signup", params: {
          email: "dup@example.com",
          nickname: "テスト",
          password: "password123",
          password_confirmation: "password123",
          target_level: "n5"
        }
      end

      it "422を返しユーザーを作成しない" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 422
        # 2. DBのアサーション
        expect(User.count).to eq 1
        # 3. 構造のアサーション
        assert_response_schema_confirm(422)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "パスワード不一致の場合" do
      before do
        post "/api/v1/auth/signup", params: {
          email: "test@example.com",
          nickname: "テスト",
          password: "password123",
          password_confirmation: "wrong",
          target_level: "n5"
        }
      end

      it "422を返しユーザーを作成しない" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 422
        # 2. DBのアサーション
        expect(User.count).to eq 0
        # 3. 構造のアサーション
        assert_response_schema_confirm(422)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
      end
    end
  end

  describe "POST /api/v1/auth/login" do
    context "正常系" do
      before do
        create(:user, email: "login@example.com", password: "password123")
        post "/api/v1/auth/login", params: { email: "login@example.com", password: "password123" }
      end

      it "トークンを返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(User.find_by(email: "login@example.com").refresh_token).to be_present
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["data"]["access_token"]).to be_present
        expect(response.parsed_body["data"]["refresh_token"]).to be_present
      end
    end

    context "パスワード誤りの場合" do
      before do
        create(:user, email: "login@example.com", password: "password123")
        post "/api/v1/auth/login", params: { email: "login@example.com", password: "wrong" }
      end

      it "401を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 401
        # 3. 構造のアサーション
        assert_response_schema_confirm(401)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "存在しないメールアドレスの場合" do
      before do
        post "/api/v1/auth/login", params: { email: "notfound@example.com", password: "password123" }
      end

      it "401を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 401
        # 2. DBのアサーション
        expect(User.count).to eq 0
        # 3. 構造のアサーション
        assert_response_schema_confirm(401)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
      end
    end
  end

  describe "POST /api/v1/auth/refresh" do
    context "正常系" do
      before do
        user = create(:user, email: "refresh@example.com", password: "password123")
        post "/api/v1/auth/login", params: { email: "refresh@example.com", password: "password123" }
        @access_token = response.parsed_body["data"]["access_token"]
        @refresh_token = response.parsed_body["data"]["refresh_token"]
        @old_refresh_token_digest = user.reload.refresh_token

        post "/api/v1/auth/refresh",
          params: { refresh_token: @refresh_token },
          headers: { "Authorization" => "Bearer #{@access_token}" }
      end

      it "新しいトークンペアを返しrefresh_tokenを更新する" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション — refresh_tokenが更新されていること
        user = User.find_by(email: "refresh@example.com")
        expect(user.refresh_token).not_to eq @old_refresh_token_digest
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["data"]["access_token"]).to be_present
        expect(response.parsed_body["data"]["refresh_token"]).to be_present
      end
    end

    context "無効なrefresh_tokenの場合" do
      before do
        create(:user, email: "refresh@example.com", password: "password123")
        post "/api/v1/auth/login", params: { email: "refresh@example.com", password: "password123" }
        @access_token = response.parsed_body["data"]["access_token"]

        post "/api/v1/auth/refresh",
          params: { refresh_token: "invalid_token" },
          headers: { "Authorization" => "Bearer #{@access_token}" }
      end

      it "401を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 401
        # 3. 構造のアサーション
        assert_response_schema_confirm(401)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    context "正常系" do
      before do
        create(:user, email: "logout@example.com", password: "password123")
        post "/api/v1/auth/login", params: { email: "logout@example.com", password: "password123" }
        @access_token = response.parsed_body["data"]["access_token"]

        delete "/api/v1/auth/logout",
          headers: { "Authorization" => "Bearer #{@access_token}" }
      end

      it "refresh_tokenを削除してsuccessを返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        user = User.find_by(email: "logout@example.com")
        expect(user.refresh_token).to be_nil
        expect(user.refresh_token_expires_at).to be_nil
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["data"]).to be_nil
      end
    end

    context "Authorizationヘッダーなしの場合" do
      before do
        delete "/api/v1/auth/logout"
      end

      it "401を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 401
        # 3. 構造のアサーション
        assert_response_schema_confirm(401)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
      end
    end
  end
end
