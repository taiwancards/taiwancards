# frozen_string_literal: true

class CollectionsController < ApplicationController
  FACETS = LexemeMemory.facets.keys.freeze
  TABS = %w[text song photo].freeze
  PER_PAGE = 120

  before_action :set_desk, only: %i[show update destroy add_item add_cards remove_item remove_items]

  rate_limit(
    to: 20,
    within: 5.minutes,
    only: %i[preview song],
    with: -> { redirect_to(new_desk_path, alert: t("desks.too_fast")) }
  )

  def index
    @groups = CollectionGroup.owned_by(current_user).ordered.to_a
    @decks = Collection.desks_for(current_user).arranged.to_a
    @decks_by_group = grouped_decks(@decks.index_by(&:id))
    grouped = @decks_by_group.values.flatten.to_set
    @ungrouped = @decks.reject { |desk| grouped.include?(desk) }
  end

  def new
    @tab = params[:tab].presence_in(TABS) || TABS.first
    @query = params[:q].to_s.strip
    @songs = @tab == "song" && @query.present? ? Songs::LrclibClient.new.search(@query) : []
    flash.now[:alert] = t("songs.no_results") if @tab == "song" && @query.present? && @songs.empty?
  end

  def song
    row = Songs::LrclibClient.new.fetch(params[:lrclib_id])
    lyrics, = Huayu::SimpToTrad.convert(row.to_h["plain"].to_s)
    if lyrics.blank?
      return redirect_to(new_desk_path(tab: "song", q: params[:q]), alert: t("songs.error_network"))
    end

    build_preview(lyrics, [row["artist"], row["track"]].compact_blank.join(" — "))
    return redirect_to(new_desk_path(tab: "song", q: params[:q]), alert: t("desks.empty_text")) if @preview.empty?

    render(:preview)
  end

  def preview
    build_preview(submitted_text, params[:name].to_s.strip)
    redirect_to(new_desk_path, alert: t("desks.empty_text")) if @preview.empty?
  end

  def mark_known
    lexemes = Lexeme.where(id: chosen_ids).to_a
    return redirect_to(new_desk_path, alert: t("desks.empty_text")) if lexemes.empty?

    result = Lexemes::KnownMarker.new(current_user).call(lexemes)
    redirect_to(desks_path, notice: t("desks.marked_known", count: result[:lexemes]))
  end

  def create
    ids = chosen_ids
    return redirect_to(new_desk_path, alert: t("desks.empty_text")) if ids.empty?

    desk = Collections::DeskBuilder.new(user: current_user).call(
      lexeme_ids: ids,
      name: params[:name],
      facets: chosen_facets
    )
    redirect_to(my_desk_path(desk), notice: notice_for(desk, ids.size))
  end

  def show
    @page = [params[:page].to_i, 1].max
    @pages = [(@desk.items_count / PER_PAGE.to_f).ceil, 1].max
    @lexemes = page_of_lexemes
    @facets = @desk.study_facets.presence || Study::CardSet::SWIPE_FACETS
    @groups = CollectionGroup.owned_by(current_user).ordered.to_a
  end

  def update
    facets = Array(params.dig(:collection, :facets)).select { |facet| FACETS.include?(facet) }
    name = params.dig(:collection, :name).to_s.strip
    @desk.update!(settings: @desk.settings.merge("facets" => facets), name: name.presence || @desk.name)
    redirect_to(my_desk_path(@desk), notice: t("desks.updated"))
  end

  def destroy
    @desk.destroy!
    redirect_to(desks_path, notice: t("desks.deleted"))
  end

  def reorder
    Collections::Reorder.call(Collection.desks_for(current_user), Array(params[:order]))
    head(:no_content)
  end

  def add_item
    lexeme = Lexeme.find_by(id: numeric_id(params[:lexeme_id]))
    if lexeme.nil?
      redirect_to(my_desk_path(@desk))
    elsif @desk.add_lexemes([lexeme.id]).zero? && @desk.room_left&.zero?
      redirect_to(my_desk_path(@desk), alert: t("desks.full", limit: Collection::MAX_ITEMS))
    else
      @desk.touch_used!
      redirect_to(my_desk_path(@desk))
    end
  end

  def add_cards
    text = submitted_text
    return redirect_to(my_desk_path(@desk), alert: t("desks.empty_text")) if text.blank?

    ids = Collections::TextPreview.new(current_user).resolve(text)
    added = @desk.add_lexemes(ids)
    @desk.touch_used!
    redirect_to(my_desk_path(@desk), notice: notice_for_added(added))
  end

  def remove_item
    @desk.remove_lexemes(numeric_id(params[:lexeme_id]))
    redirect_to(my_desk_path(@desk, page: params[:page]))
  end

  def remove_items
    removed = @desk.remove_lexemes(explicit_ids)
    redirect_to(my_desk_path(@desk, page: params[:page]), notice: t("desks.removed_cards", count: removed))
  end

  private

  def build_preview(text, name)
    @text = text
    @name = name
    @preview = Collections::TextPreview.new(current_user).call(text)
    @limit = Collection::MAX_ITEMS
  end

  def page_of_lexemes
    ids = @desk.ordered_lexeme_ids(limit: PER_PAGE, offset: (@page - 1) * PER_PAGE)
    return [] if ids.empty?

    by_id = Lexeme.where(id: ids).index_by(&:id)
    ids.filter_map { |id| by_id[id] }
  end

  def grouped_decks(by_id)
    CollectionGroupItem
      .where(collection_group_id: @groups.map(&:id))
      .order(:position)
      .pluck(:collection_group_id, :collection_id)
      .group_by(&:first)
      .transform_values { |rows| rows.filter_map { |_, deck_id| by_id[deck_id] } }
  end

  def chosen_ids
    return explicit_ids if params[:lexeme_ids].present?

    existing(Collections::Selection.unpack(params[:selection], limit: Collection::MAX_ITEMS))
  end

  def explicit_ids
    existing(Array(params[:lexeme_ids]).map(&:to_i).reject(&:zero?).uniq.first(Collection::MAX_ITEMS))
  end

  def existing(ids)
    return [] if ids.empty?

    known = Lexeme.where(id: ids).pluck(:id).to_set
    ids.select { |id| known.include?(id) }
  end

  def notice_for_added(added)
    return t("desks.full", limit: Collection::MAX_ITEMS) if added.zero? && @desk.room_left&.zero?

    t("desks.added_cards", count: added)
  end

  def notice_for(desk, requested)
    if requested > desk.items_count
      return t("desks.created_capped", kept: desk.items_count, limit: Collection::MAX_ITEMS)
    end

    t("desks.created")
  end

  def submitted_text
    upload = params[:file]
    uploaded = upload.respond_to?(:read) ? upload.read.to_s.force_encoding("UTF-8").scrub : ""
    [params[:text].to_s, uploaded].compact_blank.join("\n").first(Collections::TextPreview::MAX_CHARS)
  end

  def chosen_facets
    Array(params[:facets]).select { |facet| FACETS.include?(facet) }
  end

  def set_desk
    @desk = Collection.desks_for(current_user).find_by(id: numeric_id(params[:id]))
    raise ActiveRecord::RecordNotFound if @desk.nil?
  end
end
