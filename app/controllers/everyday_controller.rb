# frozen_string_literal: true

class EverydayController < ApplicationController
  SORTS = %w[category freq difficulty].freeze

  def index
    @collection = Collection.find_by(kind: :everyday)
    @domains = Huayu::TaiwanEverydayImporter::DOMAINS
    @origins = Huayu::TaiwanEverydayImporter::ORIGINS
    @area = params[:area].presence_in(@domains)
    @origin = params[:origin].presence_in(@origins)
    @tag = params[:tag].presence
    @sort = params[:sort].presence_in(SORTS) || SORTS.first
    @counts = domain_counts
    @lexemes = filtered
    @tags = available_tags
    @sections = sectioned
    @samples = landing_samples
  end

  helper_method :default_deck_name

  def default_deck_name
    parts = [t("everyday.title")]
    parts << t("everyday.domains.#{@area}") if @area
    parts << t("everyday.origins.#{@origin.to_s.tr("-", "_")}") if @origin
    parts << t("everyday.tags.#{@tag}", default: @tag) if @tag
    parts.join(" · ")
  end

  private

  def base_scope
    return Lexeme.none if @collection.nil?

    @collection.lexemes.visible_to(current_user)
  end

  def domain_counts
    ContentCache.fetch("everyday/domains", Lexeme.visibility_key) { count_domains }
  end

  def count_domains
    base_scope
      .reorder(nil)
      .select(
        Arel.sql("jsonb_array_elements(COALESCE(lexemes.data->'placements', '[]'::jsonb))->>'domain' AS domain_key")
      )
      .then { |inner| Lexeme.from(inner, :placed).group("placed.domain_key").count }
  end

  def filtered
    scope = base_scope.includes(:memories)
    scope = scope.where("lexemes.data->'placements' @> ?", [{domain: @area}].to_json) if @area
    scope = scope.where("lexemes.data->>'origin' = ?", @origin) if @origin
    if @tag
      scope = scope.where("lexemes.data->'placements' @> ?", [{tag: @tag}.merge(@area ? {domain: @area} : {})].to_json)
    end

    scope.reorder(order_clause)
  end

  def placement_tags(lexeme)
    Array(lexeme.data["placements"])
      .select { |row| @area.nil? || row["domain"] == @area }
      .filter_map { |row| row["tag"].presence }
      .uniq
  end

  def order_clause
    case @sort
    when "freq"
      Arel.sql(
        "(lexemes.data->>'freq_rank')::int NULLS LAST, (lexemes.data->>'difficulty')::int NULLS LAST, collection_items.position"
      )
    when "difficulty"
      Arel.sql("(lexemes.data->>'difficulty')::int NULLS LAST, collection_items.position")
    else
      Arel.sql(
        "(lexemes.data->>'tier')::int NULLS LAST, (lexemes.data->>'difficulty')::int NULLS LAST, collection_items.position"
      )
    end
  end

  def available_tags
    return [] if @area.nil?

    scope = base_scope.where("lexemes.data->'placements' @> ?", [{domain: @area}].to_json)
    scope = scope.where("lexemes.data->>'origin' = ?", @origin) if @origin
    scope.flat_map { |lexeme| placement_tags(lexeme) }.tally.sort_by { |_, count| -count }.map(&:first)
  end

  def landing_samples
    return {} unless @area.nil? && @origin.nil?

    base_scope
      .where("(lexemes.data->>'tier')::int = 1")
      .order(Arel.sql("collection_items.position"))
      .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |lexeme, index|
        placement_domains(lexeme).each { |domain| index[domain] << lexeme.text }
      end
      .transform_values { |texts| texts.first(3) }
  end

  def sectioned
    return nil if @area.nil? && @origin.nil?
    return [[nil, @lexemes.to_a]] unless @sort == "category"

    groups = Hash.new { |hash, key| hash[key] = [] }
    @lexemes.each do |lexeme|
      keys = @area ? placement_tags(lexeme) : placement_domains(lexeme)
      keys = [nil] if keys.empty?
      keys.each { |key| groups[key] << lexeme }
    end

    groups.sort_by { |group, lexemes| [group.nil? ? 1 : 0, -lexemes.size] }
  end

  def placement_domains(lexeme)
    Array(lexeme.data["placements"]).filter_map { |row| row["domain"].presence }.uniq
  end
end
