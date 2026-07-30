# frozen_string_literal: true

module Huayu
  class ClassifierExamples
    NUMERALS = "一二三四五六七八九十兩百千萬幾半這那每"
    SCAN_LIMIT = 800
    PER_NOUN = 1

    Example = Data.define(:sentence, :noun, :prefix, :highlight, :suffix)

    def for_pairs(pairs, limit:)
      return [] if pairs.empty?

      nouns = Lexeme.visible.where(kind: %i[word character], text: pairs.map(&:last).uniq).index_by(&:text)
      return [] if nouns.empty?

      wanted = pairs.select { |_classifier, noun| nouns.key?(noun) }
      hits = []
      seen = Hash.new(0)

      candidates(nouns.values.map(&:id)).each do |id, text|
        wanted.each do |classifier, noun|
          next if seen[[classifier, noun]] >= PER_NOUN

          match = pattern(classifier, noun).match(text)
          next if match.nil?

          seen[[classifier, noun]] += 1
          hits << [id, noun, match]
          break
        end

        break if hits.size >= limit
      end

      build(hits, nouns)
    end

    private

    def build(hits, nouns)
      return [] if hits.empty?

      sentences = Lexeme.where(id: hits.map(&:first)).index_by(&:id)

      hits.filter_map do |id, noun, match|
        sentence = sentences[id]
        next if sentence.nil?

        Example.new(
          sentence: sentence,
          noun: nouns.fetch(noun),
          prefix: match.pre_match,
          highlight: match[0],
          suffix: match.post_match
        )
      end
    end

    def pattern(classifier, noun)
      /[#{NUMERALS}]+#{Regexp.escape(classifier)}#{Regexp.escape(noun)}/
    end

    def candidates(noun_ids)
      ContentCache.fetch("classifier/scan", Digest::SHA256.hexdigest(noun_ids.join(",")), Lexeme.visibility_key) do
        ids = SentenceWord.where(lexeme_id: noun_ids).ranked.limit(SCAN_LIMIT).pluck(:sentence_id)
        next [] if ids.empty?

        Lexeme.visible.where(id: ids).order(:score).pluck(:id, :text)
      end
    end
  end
end
