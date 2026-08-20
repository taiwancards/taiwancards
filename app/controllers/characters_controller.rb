# frozen_string_literal: true

class CharactersController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  include Paginated
  include Filtered
  filtered_by :q

  PER_PAGE = 96

  def index
    scope = Lexeme.where(kind: :character)
    scope = scope.where("data ->> 'radical' = ?", params[:radical]) if params[:radical].present?
    @component = params[:component].presence
    scope = scope.where("data -> 'etymology' ->> 'semantic' = ?", @component) if @component
    scope = scope.where("text ILIKE ?", "%#{params[:q]}%") if params[:q].present?

    @radicals = radical_facets
    content_key = ["characters", params[:radical], @component, params[:q]].join("|")
    page, = paginate(scope.frequency_order, per_page: PER_PAGE, content_key: content_key)
    @characters = page.to_a
    @studied_ids = LexemeMemory
      .owned_by(Current.user)
      .where(lexeme_id: @characters.map(&:id))
      .where
      .not(activated_at: nil)
      .distinct
      .pluck(:lexeme_id)
      .to_set
  end

  def show
    @text = params[:text]
    lexeme = Lexeme.find_by(kind: :character, text: @text)
    return render(:missing, status: :not_found) if lexeme.nil?

    @profile = Huayu::CharacterProfile.new(lexeme)
    @word = Lexeme.visible.where(kind: Lexeme::DICTIONARY_KINDS, text: @text).order(:kind).first
    @liangci = Liangci::Sidecar.new.call(lexeme)
    @thesaurus = Lexemes::Thesaurus.new.call(lexeme)
  end

  def strokes
    raw = Huayu::StrokeData.raw(params[:text])
    return head(:not_found) if raw.nil?

    expires_in(1.year, public: true)
    render(plain: raw, content_type: "application/json")
  end

  private

  def radical_facets
    ContentCache.fetch("characters/radicals") do
      Lexeme
        .where(kind: :character)
        .where("data ->> 'radical' IS NOT NULL")
        .group("data ->> 'radical'")
        .order(Arel.sql("count(*) DESC"))
        .count
    end
  end
end
