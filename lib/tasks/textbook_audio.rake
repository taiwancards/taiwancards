# frozen_string_literal: true

namespace(:textbook) do
  desc("Download all word and phrase mp3 files into the media root (idempotent)")
  task(download_audio: :environment) do
    require "net/http"

    dir = AppData.media_path("audio/textbook")
    FileUtils.mkdir_p(dir)

    files = AppData
      .glob("data/textbook/lessons/*.json")
      .flat_map { |path| JSON.parse(path.read)["vocabulary"].filter_map { |entry| entry["audio"] } }
      .uniq
      .sort
    pending = files.reject { |file| dir.join(file).size? }
    puts("#{files.size} files total, #{pending.size} to download")

    base = Sources.url("TEXTBOOK_AUDIO_BASE_URL")
    failures = []
    pending.each_slice(200).with_index do |batch, index|
      threads = batch.each_slice((batch.size / 8.0).ceil).map do |chunk|
        Thread.new do
          chunk.each do |file|
            uri = URI("#{base}/#{file}")
            response = Net::HTTP.get_response(uri)
            if response.is_a?(Net::HTTPSuccess) && response.body.bytesize.positive?
              dir.join(file).binwrite(response.body)
            else
              failures << [file, response.code]
            end
          end
        end
      end

      threads.each(&:join)
      puts("batch #{index + 1}: #{[(index + 1) * 200, pending.size].min}/#{pending.size}")
    end

    puts(failures.empty? ? "All downloaded" : "FAILED: #{failures.inspect}")
  end
end
