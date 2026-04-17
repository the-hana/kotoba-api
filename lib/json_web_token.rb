module JsonWebToken
  SECRET_KEY = Rails.application.secret_key_base
  ACCESS_TOKEN_EXPIRY  = 15.minutes
  REFRESH_TOKEN_EXPIRY = 7.days

  def self.encode_access_token(payload)
    payload = payload.merge(exp: ACCESS_TOKEN_EXPIRY.from_now.to_i)
    JWT.encode(payload, SECRET_KEY, "HS256")
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: "HS256" })
    HashWithIndifferentAccess.new(decoded.first)
  rescue JWT::ExpiredSignature
    raise JWT::ExpiredSignature, "トークンの有効期限が切れています"
  rescue JWT::DecodeError
    raise JWT::DecodeError, "トークンが無効です"
  end
end
