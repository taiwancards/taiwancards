# frozen_string_literal: true

module Offline
  class Freshness
    TEMPLATES = %w[app/views app/helpers config/locales].freeze
    DATA = "huayu"

    def digest(section, paths)
      Digest::SHA256.hexdigest([section.id, paths.join("\n"), templates, content].join("\n"))[0, 16]
    end

    def templates
      @templates ||= Digest::SHA256.hexdigest(
        TEMPLATES.flat_map { |folder| stamps(Rails.root.join(folder)) }.sort.join("\n")
      )
    end

    def content
      @content ||= [
        newest(AppData.path(DATA)),
        Lexeme.maximum(:updated_at)&.to_i,
        Collection.maximum(:updated_at)&.to_i
      ].join("-")
    end

    private

    def stamps(folder)
      return [] unless folder.exist?

      folder.glob("**/*").select(&:file?).map { |file| "#{file}:#{file.mtime.to_i}:#{file.size}" }
    end

    def newest(folder)
      return nil unless folder&.exist?

      folder.glob("**/*.json*").select(&:file?).map { |file| file.mtime.to_i }.max
    end
  end
end
