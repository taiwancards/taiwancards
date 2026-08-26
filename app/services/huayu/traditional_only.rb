# frozen_string_literal: true

module Huayu
  module TraditionalOnly
    SPAN = /[\p{Han}《》〈〉「」『』〔〕・·]+/
    DOUBLET = /(#{SPAN})[[:blank:]]*[／\/][[:blank:]]*(#{SPAN})/
    RUN = /\p{Han}+/
    CLAUSE = /([，、])/

    module_function

    PASSES = 3

    def normalize(text)
      body = text.to_s.strip
      return body if body.empty?

      PASSES.times do
        fresh = sweep(body)
        break if fresh == body

        body = fresh
      end

      body
    end

    def sweep(text)
      body = collapse_doublets(text)
      body = drop_repeated_clauses(body)
      convert_runs(body)
    end

    def simplified(text)
      text.to_s.each_char.select { |char| simplified?(char) }.uniq
    end

    def simplified?(char)
      swap = SimpToTrad.table[char]
      return false if swap.blank? || swap == char

      simplified_only.include?(char) || !Traditional.char?(char)
    end

    def simplified_only = TWFilter::Tables.set("simplified_only.txt")

    def collapse_doublets(text)
      text.gsub(DOUBLET) do |match|
        traditional = Regexp.last_match(1)
        SimpToTrad.convert(Regexp.last_match(2)).first == traditional ? traditional : match
      end
    end

    def drop_repeated_clauses(text)
      previous = nil
      parts = []

      text.split(CLAUSE).each_slice(2) do |segment, separator|
        opening = segment[/\A#{RUN}/]
        repeated = echoes?(opening, previous)
        kept = repeated ? segment.sub(opening, "") : segment
        previous = kept.scan(RUN).last

        parts.pop if repeated && parts.last&.match?(CLAUSE)
        parts << kept
        parts << separator if separator
      end

      parts.join
    end

    def echoes?(opening, previous)
      return false if opening.blank? || previous.blank?

      simplified(opening).any? && SimpToTrad.convert(opening).first == previous
    end

    def to_traditional(text, keep: nil)
      text
        .to_s
        .each_char
        .map { |char|
          next char if keep&.include?(char)

          simplified?(char) ? SimpToTrad.table[char] : char
        }
        .join
    end

    def convert_runs(text)
      text.gsub(RUN) do |run|
        next run if run.length < 2 || run.each_char.none? { |char| simplified?(char) }

        to_traditional(run)
      end
    end
  end
end
