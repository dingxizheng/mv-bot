# frozen_string_literal: true

Yt.configure do |config|
  config.client_id = ENV["GOOGLE_CLIENT_ID"]
  config.client_secret = ENV["GOOGLE_CLIENT_SECRET"]
end

class YoutubeManager
  class << self
    def authentication_url
      Yt::Account.new(scopes: ["youtube", "userinfo.email"], redirect_uri: "http://localhost:3333").authentication_url
    end

    def account
      @account ||= Yt::Account.new(refresh_token: youtube_credentials["refresh_token"])
    end

    def youtube_credentials
      @credentials ||= YAML::load_file("./youtube-credentials.yaml")["default"].then(&JSON.method(:parse))
    end
  end
end