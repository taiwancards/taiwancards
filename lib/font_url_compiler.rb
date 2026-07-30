# frozen_string_literal: true

class FontUrlCompiler < Propshaft::Compiler
  PATTERN = %r{url\(["']?#{FontAssets::MOUNT}/([^"')]+)["']?\)}

  def compile(_asset, input)
    return input if FontAssets.base_url.nil?

    input.gsub(PATTERN) { "url(\"#{FontAssets.url_for(Regexp.last_match(1))}\")" }
  end
end
