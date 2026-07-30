# frozen_string_literal: true

module LexemeLinksHelper
  LINK_CLASSES = "underline decoration-dotted underline-offset-4 transition-colors " \
    "decoration-muted-foreground/40 hover:decoration-current"

  def preload_lexeme_links(texts)
    wanted = Array(texts).compact_blank.uniq
    return @linkable_lexemes = {} if wanted.empty?

    @linkable_lexemes = Lexeme
      .visible_to(Current.user)
      .where(text: wanted)
      .pluck(:text, :kind)
      .to_h { |text, kind| [text, kind.is_a?(Integer) ? Lexeme.kinds.key(kind) : kind.to_s] }
  end

  def lexeme_link_path(text)
    kind = linkable_lexemes[text]
    return if kind.nil?

    kind == "character" ? character_path(text) : dict_entry_path(text)
  end

  def lexeme_link(text, css: nil)
    return tag.span(text, lang: "zh-TW", class: css) if text.blank?

    path = lexeme_link_path(text)
    return tag.span(text, lang: "zh-TW", class: css) if path.nil?

    link_to(text, path, lang: "zh-TW", class: class_names(css, LINK_CLASSES))
  end

  private

  def linkable_lexemes
    @linkable_lexemes ||= {}
  end
end
