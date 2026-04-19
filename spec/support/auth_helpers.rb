module AuthHelpers
  # テスト用JWTトークンを生成するヘルパー
  def auth_headers(user)
    token = JsonWebToken.encode_access_token(user_id: user.id)
    { "Authorization" => "Bearer #{token}" }
  end
end
