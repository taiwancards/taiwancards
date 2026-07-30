# frozen_string_literal: true

require "net/http"

module Google
  class DriveClient
    class Error < StandardError
    end

    TOKEN_URL = "https://oauth2.googleapis.com/token"
    UPLOAD_URL = "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name"
    FILES_URL = "https://www.googleapis.com/drive/v3/files"
    NAME_PREFIX = "taiwancards-progress-"

    def initialize(user)
      @user = user
    end

    def upload(name:, content:, mime: "application/gzip")
      boundary = "taiwancards-#{SecureRandom.hex(8)}"
      body = +"--#{boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n"
      body << {name:}.to_json
      body << "\r\n--#{boundary}\r\nContent-Type: #{mime}\r\n\r\n"
      body << content
      body << "\r\n--#{boundary}--"
      JSON.parse(request(:post, UPLOAD_URL, body:, content_type: "multipart/related; boundary=#{boundary}"))
    end

    def backups
      uri = URI(FILES_URL)
      uri.query = URI.encode_www_form(
        q: "name contains '#{NAME_PREFIX}' and trashed = false",
        orderBy: "createdTime desc",
        fields: "files(id,name,createdTime)",
        pageSize: 50
      )
      JSON.parse(request(:get, uri.to_s)).fetch("files", [])
    end

    def download(file_id)
      request(:get, "#{FILES_URL}/#{file_id}?alt=media")
    end

    private

    def access_token
      refresh! if token_expired?
      @user.google_access_token
    end

    def token_expired?
      @user.google_access_token.blank? ||
        @user.google_token_expires_at.nil? ||
        @user.google_token_expires_at <= 1.minute.from_now
    end

    def refresh!
      raise Error, "Google account is not connected" if @user.google_refresh_token.blank?

      response = Net::HTTP.post_form(
        URI(TOKEN_URL),
        "grant_type" => "refresh_token",
        "refresh_token" => @user.google_refresh_token,
        "client_id" => ENV["GOOGLE_OAUTH_CLIENT_ID"],
        "client_secret" => ENV["GOOGLE_OAUTH_CLIENT_SECRET"]
      )
      data = JSON.parse(response.body)
      raise Error, data["error_description"] || "Token refresh failed" if data["access_token"].blank?

      @user.update!(
        google_access_token: data["access_token"],
        google_token_expires_at: Time.current + data["expires_in"].to_i.seconds
      )
    end

    def request(method, url, body: nil, content_type: nil)
      uri = URI(url)
      klass = (method == :post) ? Net::HTTP::Post : Net::HTTP::Get
      req = klass.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      req["Content-Type"] = content_type if content_type
      req.body = body if body

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(req)
      unless response.code.to_i.between?(200, 299)
        raise Error, "Google Drive API #{response.code}"
      end

      response.body
    end
  end
end
