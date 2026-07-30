# frozen_string_literal: true

require "zlib"
require "stringio"

module Progress
  class DriveBackup
    def initialize(user, client: Google::DriveClient.new(user))
      @user = user
      @client = client
    end

    def save
      json = JSON.generate(Progress::Export.new(@user).call)
      name = "taiwancards-progress-#{Time.current.strftime("%Y-%m-%d-%H%M%S")}.json.gz"
      @client.upload(name:, content: gzip(json))
      name
    end

    def restore(file_id = nil)
      file_id ||= @client.backups.first&.fetch("id", nil)
      raise Google::DriveClient::Error, "No backup found on Drive" if file_id.blank?

      json = JSON.parse(gunzip(@client.download(file_id)))
      Progress::Import.new(@user).call(json)
    end

    def list
      @client.backups
    end

    private

    def gzip(string)
      io = StringIO.new
      gz = Zlib::GzipWriter.new(io)
      gz.write(string)
      gz.close
      io.string
    end

    def gunzip(binary)
      Zlib::GzipReader.new(StringIO.new(binary)).read
    end
  end
end
