# frozen_string_literal: true

module Deploy
  class DictionaryDump
    KINDS = %w[character word collocation radical measure_word].freeze

    COLUMNS = %w[kind text readings meanings data sources score search_text restricted].freeze

    ESCAPES = {"\\" => "\\\\", "\t" => "\\t", "\n" => "\\n", "\r" => "\\r"}.freeze

    def initialize(kinds)
      @kinds = kinds
    end

    def write(path)
      written = 0
      path.open("w") do |file|
        scope.find_each(batch_size: 2_000) do |lexeme|
          file.puts(line(lexeme))
          written += 1
        end
      end

      written
    end

    private

    def scope
      Lexeme
        .where(kind: @kinds)
        .select(:id, :kind, :text, :readings, :meanings, :data, :sources, :score, :search_text, :restricted)
    end

    def line(lexeme)
      [
        Lexeme.kinds.fetch(lexeme.kind),
        escape(lexeme.text),
        escape(JSON.generate(lexeme.readings)),
        escape(JSON.generate(lexeme.meanings)),
        escape(JSON.generate(lexeme.data)),
        escape(JSON.generate(lexeme.sources)),
        lexeme.score || "\\N",
        lexeme.search_text.nil? ? "\\N" : escape(lexeme.search_text),
        lexeme.restricted
      ].join("\t")
    end

    def escape(value)
      value.to_s.gsub(/[\\\t\n\r]/) { |char| ESCAPES[char] }
    end
  end
end
