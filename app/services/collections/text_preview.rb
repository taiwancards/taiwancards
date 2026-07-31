# frozen_string_literal: true

module Collections
  class TextPreview
    MAX_CHARS = 30_000
    FOREIGN = 0
    UNLISTED = 1
    CANDIDATE = 2

    Result = Data.define(:lines, :candidates, :coverage, :chars, :truncated) do
      def empty? = candidates.empty?

      def candidate_ids = candidates.map { |entry| entry[:id] }
    end

    def initialize(user = Current.user, analyzer: nil)
      @user = user
      @analyzer = analyzer
    end

    def call(text)
      raw = text.to_s
      truncated = raw.length > MAX_CHARS
      body = truncated ? raw[0, MAX_CHARS] : raw
      lines, ids = tokenize(body)
      build(lines, ids, body, truncated)
    end

    def resolve(text)
      raw = text.to_s
      body = raw.length > MAX_CHARS ? raw[0, MAX_CHARS] : raw
      tokenize(body).last
    end

    private

    def build(lines, ids, body, truncated)
      lexemes = Lexeme.where(id: ids).index_by(&:id)
      ordered = ids.filter_map { |id| lexemes[id] }
      coverage = Collections::Coverage.new(@user).call(ordered.map(&:id))

      Result.new(
        lines:,
        candidates: ordered.each_with_index.map { |lexeme, index| entry(lexeme, index, coverage) },
        coverage:,
        chars: body.length,
        truncated:
      )
    end

    def tokenize(body)
      parsed = analyzer.analyze_lines(body.lines.map(&:chomp))
      slots = {}
      ids = []
      lines = parsed.map { |tokens| tokens.map { |token| render(token, slots, ids) } }
      [lines, ids]
    end

    def render(token, slots, ids)
      return {t: token.text, k: FOREIGN} if token.kind == :literal
      return {t: token.text, k: UNLISTED} if token.lexeme.nil?

      slot = slots[token.lexeme.id] ||= begin
        ids << token.lexeme.id
        ids.size - 1
      end

      {t: token.text, k: CANDIDATE, w: slot}
    end

    def entry(lexeme, index, coverage)
      {
        i: index,
        id: lexeme.id,
        t: lexeme.text,
        k: lexeme.kind,
        r: reading_for(lexeme),
        m: lexeme.meaning.to_s.truncate(160),
        l: lexeme.data["tocfl_level"].presence,
        b: lexeme.data["tbcl_grade"].presence,
        f: lexeme.freq_rank,
        c: lexeme.score&.round(1),
        u: url_for_lexeme(lexeme),
        s: coverage.studied.include?(lexeme.id),
        d: coverage.in_decks.include?(lexeme.id)
      }
    end

    def url_for_lexeme(lexeme)
      case lexeme.kind
      when "character"
        "/characters/#{CGI.escape(lexeme.text)}"
      when "radical"
        "/radicals/#{CGI.escape(lexeme.text)}"
      when "measure_word"
        "/liangci/#{CGI.escape(lexeme.text)}"
      else
        "/dict/#{CGI.escape(lexeme.text)}"
      end
    end

    def reading_for(lexeme)
      first = lexeme.reading_set.first
      (first&.dig("zhuyin").presence || first&.dig("pinyin")).to_s
    end

    def analyzer
      @analyzer ||= Huayu::TextAnalyzer.new(locale: I18n.locale)
    end
  end
end
