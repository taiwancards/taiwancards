# frozen_string_literal: true

module Lexemes
  class ProjectionPreview
    KINDS = %w[character word].freeze

    def initialize(user)
      @user = user
    end

    def total = counts["total"].to_i

    def visible = counts["visible"].to_i

    def hidden = total - visible

    def share = total.zero? ? 0 : (hidden * 100.0 / total).round

    private

    def counts
      @counts ||= ContentCache.fetch("projection", Lexeme.visibility_key(@user)) do
        scope = Lexeme.permitted_to(@user).where(kind: KINDS)
        {"total" => scope.count, "visible" => scope.projected_for(@user).count}
      end
    end
  end
end
