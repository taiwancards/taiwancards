# frozen_string_literal: true

module GrammarHelper
  def grammar_example_ruby(example, css: nil)
    syllables = example.zhuyin.to_s.split(/[[:space:]]+/).reject(&:empty?)
    queue = syllables.dup

    tag.span(lang: "zh-TW", class: class_names("zy-run", grammar_zhuyin_run_class, css)) do
      safe_join(
        example.zh.chars.map do |char|
          if char.match?(/\p{Han}/) && queue.any?
            zhuyin_ruby_pair(char, queue.shift)
          else
            tag.span(char)
          end
        end
      )
    end
  end

  def grammar_zhuyin_run_class
    zhuyin_position_for(:body) == "over" ? "zy-over" : "zy-right"
  end
end
