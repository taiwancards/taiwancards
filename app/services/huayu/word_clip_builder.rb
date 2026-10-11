# frozen_string_literal: true

require "open3"

module Huayu
  class WordClipBuilder
    RATE = 22_050
    PAD_BEFORE_MS = 60
    PAD_AFTER_MS = 90
    FADE_MS = 15
    JOINT_FADE_MS = 40
    MIN_SCORE = 80
    GOOD_ENOUGH = 92
    SANDHI_MARGIN = 5
    GRADE_PAD_MS = 400
    CANDIDATES = 6
    WEAK_LEVELS = %w[red dark].freeze
    NOT_HAN = /\P{Han}/
    PHRASES = "pronunciation/corpus_cv/manifest.json"
    PHRASE_AUDIO = "pronunciation/corpus_cv/audio"
    LISTENING_AUDIO = "listening/audio"
    SOURCE = "Common Voice zh-TW (CC0-1.0), cut from Taiwan-born speakers' recordings"

    Source = Data.define(:text, :path, :lexeme)
    Cut = Data.define(:word, :sentence, :score, :wav, :source)

    def self.starter_words
      StarterTrack.lessons.flat_map(&:words).map(&:zh).uniq.select { |text|
        text.length > 1 && MoeAudio.for(text).nil?
      }
    end

    def initialize(
      words:,
      out: AppData.media_path("word_clips"),
      log: $stdout,
      backend: Pronunciation::AcousticBackend.new
    )
      @words = words
      @out = out
      @log = log
      @backend = backend
    end

    def call
      clips = existing
      Dir.mktmpdir do |tmp|
        @tmp = tmp
        @words.each do |word|
          cut = best_cut(word)
          @log.puts(cut ? "#{word}: #{cut.score} from #{cut.sentence}" : "#{word}: no clean recording")
          cut ? clips[word] = publish(cut) : clips.delete(word)
        end
      end

      write(clips)
      clips.size
    end

    private

    def best_cut(word)
      target = Lexeme.where(kind: %i[word character]).find_by(text: word)
      rows = target && PronunciationTarget.new(target).syllables
      return nil if rows.blank? || rows.size != word.length

      best = nil
      sources_for(word).first(CANDIDATES).each do |source|
        cut = cut_from(source, word, rows)
        best = cut if cut && (best.nil? || cut.score > best.score)
        break if best && best.score >= GOOD_ENOUGH
      end

      best
    end

    def sources_for(word)
      sources
        .select { |source| source.text == word || (source.lexeme && source.text.include?(word)) }
        .sort_by { |source|
          [
            source.text == word ? 0 : 1,
            standalone?(source, word) ? 0 : 1,
            source.text.end_with?(word) ? 0 : 1,
            source.text.length
          ]
        }
    end

    def standalone?(source, word) = Array(source.lexeme&.data&.dig("segments")).include?(word)

    def sources
      @sources ||= phrase_sources + listening_sources
    end

    def phrase_sources
      manifest = AppData.media_path(PHRASES)
      return [] unless manifest.exist?

      JSON.parse(manifest.read).fetch("clips", {}).filter_map do |_name, row|
        path = AppData.media_path(PHRASE_AUDIO).join(File.basename(row["path"].to_s))
        Source.new(text: row["sentence"].to_s.gsub(NOT_HAN, ""), path:, lexeme: nil) if path.exist?
      end
    end

    def listening_sources
      sentences = Lexeme.where(kind: :sentence, text: ListeningClips.all.map(&:text)).index_by(&:text)
      ListeningClips.all.filter_map do |row|
        path = AppData.media_path(LISTENING_AUDIO).join(row.clip)
        lexeme = sentences[row.text]
        Source.new(text: row.text.gsub(NOT_HAN, ""), path:, lexeme:) if lexeme && path.exist?
      end
    end

    def cut_from(source, word, word_rows)
      wav = convert(source.path)
      return nil if wav.nil?

      rows = source.text == word ? word_rows : source.lexeme && PronunciationTarget.new(source.lexeme).syllables
      return nil if rows.blank?

      start = rows.map { |row| row["char"] }.join.index(word)
      return nil if start.nil? || rows.size != source.text.length

      spans = @backend.syllable_spans(audio: File.binread(wav), syllables: rows)
      return nil if spans.nil? || spans.size != rows.size

      last = start + word.length - 1
      clip = trim(wav, window(spans, start, last), joint: last < rows.size - 1)
      grade(word, word_rows, clip, source.text, source.path)
    end

    def window(spans, first, last)
      from = spans[first][0] - PAD_BEFORE_MS
      from = [from, spans[first - 1][1]].max if first.positive?
      to = spans[last + 1] ? spans[last][1] : spans[last][1] + PAD_AFTER_MS
      [[from, 0].max, to]
    end

    def grade(word, rows, wav, sentence, source)
      heard = padded(wav)
      return nil if heard.nil?

      result = @backend.grade(audio: File.binread(heard), text: word, syllables: rows, takes: 1)
      syllables = Array(result&.dig("syllables"))
      if syllables.size != rows.size || syllables.any? { |row| row.nil? || WEAK_LEVELS.include?(row["level"]) }
        return nil
      end

      return nil unless sandhi_heard?(word, rows, heard, syllables)

      score = result["overall"].to_i
      score >= MIN_SCORE ? Cut.new(word:, sentence:, score:, wav:, source:) : nil
    end

    def sandhi_heard?(word, rows, wav, syllables)
      shifted = rows.each_index.select { |index| rows[index]["tone"] != rows[index]["base_tone"] }
      return true if shifted.empty?

      plain = @backend.grade(audio: File.binread(wav), text: word, syllables: TextReading.unshifted(rows), takes: 1)
      heard = Array(plain&.dig("syllables"))
      shifted.all? { |index| tone_score(syllables[index]) >= tone_score(heard[index]) + SANDHI_MARGIN }
    end

    def tone_score(syllable) = syllable&.dig("cells", "tone", "score").to_i

    def convert(path)
      target = File.join(@tmp, "#{Digest::SHA1.hexdigest(path.to_s)}.wav")
      return target if File.exist?(target)

      ffmpeg("-i", path.to_s, "-ac", "1", "-ar", RATE.to_s, target) ? target : nil
    end

    def trim(wav, (from, to), joint:)
      seconds = (to - from) / 1000.0
      fade = FADE_MS / 1000.0
      tail = (joint ? JOINT_FADE_MS : FADE_MS) / 1000.0
      target = File.join(@tmp, "#{File.basename(wav, ".wav")}-#{from}-#{to}.wav")
      filters = "afade=t=in:st=0:d=#{fade},afade=t=out:st=#{(seconds - tail).round(3)}:d=#{tail}"
      ffmpeg("-ss", (from / 1000.0).to_s, "-t", seconds.to_s, "-i", wav, "-af", filters, target) ? target : nil
    end

    def padded(wav)
      target = "#{wav.delete_suffix(".wav")}-padded.wav"
      seconds = GRADE_PAD_MS / 1000.0
      filters = "adelay=#{GRADE_PAD_MS}|#{GRADE_PAD_MS},apad=pad_dur=#{seconds}"
      ffmpeg("-i", wav, "-af", filters, target) ? target : nil
    end

    def publish(cut)
      name = "#{Digest::SHA1.hexdigest("#{cut.word}:#{cut.sentence}:#{File.basename(cut.source.to_s)}")[0, 16]}.mp3"
      audio = @out.join("audio")
      FileUtils.mkdir_p(audio)
      ffmpeg("-i", cut.wav, "-af", "loudnorm=I=-18:TP=-2", "-codec:a", "libmp3lame", "-q:a", "4", audio.join(name).to_s)
      {"clip" => name, "sentence" => cut.sentence, "score" => cut.score}
    end

    def ffmpeg(*arguments)
      _output, status = Open3.capture2e("ffmpeg", "-y", "-loglevel", "error", *arguments)
      status.success?
    end

    def existing
      manifest = @out.join("manifest.json")
      manifest.exist? ? JSON.parse(manifest.read).fetch("clips", {}) : {}
    end

    def write(clips)
      FileUtils.mkdir_p(@out)
      payload = {"source" => SOURCE, "license" => "CC0-1.0", "clips" => clips.sort.to_h}
      @out.join("manifest.json").write("#{JSON.pretty_generate(payload)}\n")
    end
  end
end
