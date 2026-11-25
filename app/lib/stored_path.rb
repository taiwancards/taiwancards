# frozen_string_literal: true

module StoredPath
  CUT_ESCAPE = /%\h?\z/
  LAST_ESCAPE = /%\h\h\z/
  ESCAPE_RUN = /(?:%\h\h)+\z/
  LONGEST_CHARACTER = 4
  INVISIBLE = /[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/

  module_function

  def clip(path, limit)
    full = path.to_s
    return full if full.length <= limit

    cut = full.first(limit).sub(CUT_ESCAPE, "")
    LONGEST_CHARACTER.times do
      break if whole_characters?(cut[ESCAPE_RUN].to_s)

      cut = cut.sub(LAST_ESCAPE, "")
    end

    cut
  end

  def readable(path)
    text(Rack::Utils.unescape_path(path.to_s.sub(CUT_ESCAPE, "")))
  end

  def text(bytes) = visible(bytes.to_s.dup.force_encoding(Encoding::UTF_8).scrub(""))

  def visible(text) = text.to_s.gsub(INVISIBLE, "")

  def whole_characters?(escapes)
    Rack::Utils.unescape_path(escapes).dup.force_encoding(Encoding::UTF_8).valid_encoding?
  end

  private_class_method(:whole_characters?)
end
