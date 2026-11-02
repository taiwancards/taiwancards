# frozen_string_literal: true

module Huayu
  class AuthoredSentenceImporter < CuratedSentenceImporter
    SOURCE = "taiwancards_examples"
    MARKER = "authored"
    PATH = AppData.path("huayu/authored_sentences.json")

    private

    def wanted
      @wanted ||= JSON.parse(File.read(PATH)).to_h do |row|
        [row.fetch("zh"), row.slice(*Locales::ALL).compact_blank]
      end
    end
  end
end
