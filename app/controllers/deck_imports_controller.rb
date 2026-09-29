# frozen_string_literal: true

class DeckImportsController < ApplicationController
  rate_limit(
    to: 10,
    within: 5.minutes,
    only: %i[preview create],
    with: -> { redirect_to(new_desk_path(tab: "import"), alert: t("desks.too_fast")) }
  )

  def preview
    @source = params[:source].presence_in(Collections::Import::Parser::SOURCES)
    return back_with(t("imports.pick_source")) if @source.nil?

    text = submitted_text
    return back_with(t("imports.too_big", limit: Collections::Import::Parser::MAX_BYTES / 1024 / 1024)) if text.nil?

    @parsed = Collections::Import::Parser.call(@source, text)
    return back_with(t("imports.unreadable")) if @parsed.unreadable || @parsed.empty?

    @result = Collections::Import::Resolver.new(current_user).call(@parsed.rows)
    @name = params[:name].to_s.strip.presence || t("imports.default_name", source: t("imports.sources.#{@source}.name"))
    @limit = Collection::MAX_ITEMS
  end

  def create
    ids = chosen_ids
    return back_with(t("desks.empty_text")) if ids.empty?

    kept = ids.first(Collection::MAX_ITEMS)
    desk = Collections::DeskBuilder.new(user: current_user).call(
      lexeme_ids: kept,
      name: params[:name].to_s.strip.presence || t("imports.default_name", source: "TaiwanCards"),
      facets: Array(params[:facets]).select { |facet| LexemeMemory.facets.key?(facet) }
    )
    redirect_to(my_desk_path(desk), notice: t("imports.created", count: desk.items_count))
  end

  private

  def back_with(message) = redirect_to(new_desk_path(tab: "import"), alert: message)

  def submitted_text
    upload = params[:file]
    if upload.respond_to?(:read)
      return nil if upload.size > Collections::Import::Parser::MAX_BYTES

      return upload.read
    end

    text = params[:text].to_s
    text.bytesize > Collections::Import::Parser::MAX_BYTES ? nil : text
  end

  def chosen_ids
    wanted = Collections::Selection.unpack(params[:selection], limit: Collection::MAX_ITEMS)
    wanted += picked(values(params[:picks]))
    wanted += picked(params[:swaps])
    wanted = visible(wanted.uniq)
    return wanted unless params[:skip_covered] == "1"

    covered = Collections::Coverage.new(current_user).covered_ids(wanted)
    wanted.reject { |id| covered.include?(id) }
  end

  def values(field) = field.respond_to?(:values) ? field.values : field

  def picked(values) = Array(values).map(&:to_i).select(&:positive?)

  def visible(ids)
    return [] if ids.empty?

    found = Lexeme.visible_to(current_user).where(id: ids).pluck(:id).to_set
    ids.select { |id| found.include?(id) }
  end
end
