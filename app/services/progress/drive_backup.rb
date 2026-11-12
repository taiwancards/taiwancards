# frozen_string_literal: true

require "zlib"
require "stringio"

module Progress
  class DriveBackup
    LIMIT = 64.megabytes
    UNREADABLE = "The backup on Drive could not be read"

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

      Progress::Import.new(@user).call(decode(@client.download(file_id)))
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

    def decode(binary)
      data = JSON.parse(gunzip(binary))
      raise Google::DriveClient::Error, UNREADABLE unless data.is_a?(Hash)

      data
    rescue JSON::ParserError, Zlib::Error
      raise Google::DriveClient::Error, UNREADABLE
    end

    def gunzip(binary)
      reader = Zlib::GzipReader.new(StringIO.new(binary.to_s))
      text = reader.read(LIMIT + 1).to_s
      if text.bytesize > LIMIT
        raise Google::DriveClient::Error, "The backup on Drive is larger than #{LIMIT / 1.megabyte} MB"
      end

      text.force_encoding(Encoding::UTF_8)
    ensure
      reader&.close
    end
  end
end
