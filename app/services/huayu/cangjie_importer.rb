# frozen_string_literal: true

module Huayu
  class CangjieImporter
    PATH = AppData.path("dictionaries/cangjie5.tsv")
    LOOKUP = SharedAssets.directory("json").join("cangjie5.json")

    def initialize(path: PATH)
      @path = Pathname(path)
    end

    def call
      char_code, code_chars = load
      write_lookup(code_chars)
      tagged = tag_characters(char_code)
      {codes: char_code.size, lookup_codes: code_chars.size, tagged:}
    end

    private

    def load
      char_code = {}
      code_chars = Hash.new { |hash, key| hash[key] = [] }
      @path.each_line(chomp: true) do |line|
        char, code = line.split("\t", 2)
        next if char.blank? || code.blank?

        char_code[char] ||= Cangjie.canonical(char, code)
        code_chars[code] << char unless code_chars[code].include?(char)
      end

      [char_code, code_chars]
    end

    def write_lookup(code_chars)
      LOOKUP.write(JSON.generate(code_chars))
    end

    def tag_characters(char_code)
      count = 0
      Lexeme.where(kind: :character, text: char_code.keys).find_each do |lexeme|
        code = char_code[lexeme.text]
        next if lexeme.data["cangjie"] == code

        lexeme.update!(data: lexeme.data.merge("cangjie" => code))
        count += 1
      end

      count
    end
  end
end
