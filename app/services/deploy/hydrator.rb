# frozen_string_literal: true

module Deploy
  class Hydrator
    PREFIXES = {
      "huayu" => :data,
      "textbook" => :data,
      "dictionaries" => :data,
      "pronunciation" => :data,
      "content_sources.json" => :data,
      "fonts.json" => :data,
      "media/listening" => :media,
      "media/moe_audio" => :media,
      "media/moe_audio_words" => :media
    }.freeze

    ARCHIVES = {"pronunciation/templates.tar.gz" => "pronunciation"}.freeze
    THREADS = 16
    Result = Struct.new(:downloaded, :skipped, :bytes, keyword_init: true)

    def initialize(io: $stdout, data_root: Rails.root.join("data"), media_root: Rails.root.join("media"))
      @io = io
      @roots = {data: Pathname(data_root), media: Pathname(media_root)}
    end

    def call
      return skip unless Storage::Bucket.configured?

      started = Time.current
      result = Result.new(downloaded: 0, skipped: 0, bytes: 0)
      PREFIXES.each_key { |prefix| fetch(prefix, result) }

      @io.puts(
        format(
          "hydrate: %d files (%.1f MB), %d already current, %.1fs",
          result.downloaded,
          result.bytes / 1024.0 / 1024,
          result.skipped,
          Time.current - started
        )
      )
      result
    end

    private

    def skip
      @io.puts("hydrate: R2 is not configured; leaving the local tree alone")
      Result.new(downloaded: 0, skipped: 0, bytes: 0)
    end

    def bucket = @bucket ||= Storage::Bucket.runtime

    def fetch(prefix, result)
      queue = Queue.new
      bucket.each_object(prefix) { |key, size| queue << [key, size] }
      total = queue.size
      return if total.zero?

      lock = Mutex.new
      workers = Array.new([THREADS, total].min) do
        Thread.new do
          while (item = pop(queue))
            key, size = item
            downloaded = store(key, size)
            lock.synchronize do
              downloaded ? (result.downloaded += 1) && (result.bytes += size) : result.skipped += 1
            end
          end
        end
      end

      workers.each(&:join)
    end

    def pop(queue)
      queue.pop(true)
    rescue ThreadError
      nil
    end

    def store(key, size)
      return unpack(key, size) if ARCHIVES.key?(key)

      path = target(key)
      return false if path.exist? && path.size == size

      bucket.download(key, path)
      true
    end

    def unpack(key, size)
      into = @roots.fetch(:data).join(ARCHIVES.fetch(key))
      stamp = into.join(".#{File.basename(key)}.size")
      return false if stamp.exist? && stamp.read.to_i == size

      archive = Pathname(Dir.mktmpdir).join(File.basename(key))
      bucket.download(key, archive)
      into.mkpath
      raise "could not unpack #{key}" unless system("tar", "-xzf", archive.to_s, "-C", into.to_s)

      stamp.write(size.to_s)
      archive.dirname.rmtree
      true
    end

    def target(key)
      root, relative = if key.start_with?("media/")
        [@roots.fetch(:media), key.delete_prefix("media/")]
      else
        [@roots.fetch(:data), key]
      end

      root.join(relative)
    end
  end
end
