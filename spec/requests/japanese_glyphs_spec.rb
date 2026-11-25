# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mandarin on Japanese pages", :no_auth do
  def stray_han(path)
    get(path)
    document = Nokogiri::HTML5(response.body)
    document.css("script, style, title").each(&:remove)
    document.at_css("main").xpath(".//text()").select do |node|
      node.text.match?(/\p{Han}/) &&
        node.text.match?(/\p{Latin}/) &&
        !node.text.match?(/[\p{Hiragana}\p{Katakana}]/) &&
        node.ancestors.find { |element| element.respond_to?(:[]) && element["lang"] }&.[]("lang") == "ja"
    end
  end

  it "gives every Mandarin word of an untranslated English explanation the Taiwan language tag" do
    lesson = Huayu::GrammarLessons.lessons.find { |entry| entry.body(:en).to_s.match?(/\p{Han}/) && entry.ja.blank? }
    skip("every lesson has a Japanese text") if lesson.nil?

    expect(stray_han("/ja/grammar/#{lesson.slug}").map(&:text)).to(eq([]))
  end
end
