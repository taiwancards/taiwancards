# frozen_string_literal: true

class CollectionsController < ApplicationController
  FACETS = LexemeMemory.facets.keys.freeze

  before_action :set_language
  before_action :set_desk, only: %i[show update destroy add_item remove_item]

  def index
    @desks = Collection.desks_for(current_user).recent.to_a
  end

  TABS = %w[text song photo].freeze

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

    resolve(lyrics, [row["artist"], row["track"]].compact_blank.join(" — "))
    return redirect_to(new_desk_path(tab: "song", q: params[:q]), alert: t("desks.empty_text")) if @result.empty?

    render(:preview)
  end

  def preview
    resolve(submitted_text, params[:name].to_s.strip)
    redirect_to(new_desk_path, alert: t("desks.empty_text")) if @result.empty?
  end

  def mark_known
    lexemes = Lexeme.where(id: Array(params[:lexeme_ids]).reject(&:blank?)).to_a
    return redirect_to(new_desk_path, alert: t("desks.empty_text")) if lexemes.empty?

    result = Lexemes::KnownMarker.new(current_user).call(lexemes)
    redirect_to(desks_path, notice: t("desks.marked_known", count: result[:lexemes]))
  end

  def create
    lexemes = Lexeme.where(id: Array(params[:lexeme_ids]).reject(&:blank?)).to_a
    return redirect_to(new_desk_path, alert: t("desks.empty_text")) if lexemes.empty?

    desk = Collections::DeskBuilder.new.call(lexemes:, name: params[:name], facets: chosen_facets)
    redirect_to(my_desk_path(desk), notice: t("desks.created"))
  end

  def show
    @lexemes = @desk.lexemes.to_a
    @facets = @desk.study_facets.presence || Study::CardSet::SWIPE_FACETS
  end

  def update
    facets = Array(params.dig(:collection, :facets)).select { |facet| FACETS.include?(facet) }
    name = params.dig(:collection, :name).to_s.strip
    @desk.update!(
      settings: @desk.settings.merge("facets" => facets),
      name: name.presence || @desk.name
    )
    redirect_to(my_desk_path(@desk), notice: t("desks.updated"))
  end

  def destroy
    @desk.destroy!
    redirect_to(desks_path, notice: t("desks.deleted"))
  end

  def add_item
    lexeme = Lexeme.find_by(id: params[:lexeme_id])
    if lexeme
      @desk.add_lexeme(lexeme)
      Lexemes::Activator.new.call(lexeme)
      @desk.touch_used!
    end

    redirect_to(my_desk_path(@desk))
  end

  def remove_item
    @desk.collection_items.where(lexeme_id: params[:lexeme_id]).destroy_all
    redirect_to(my_desk_path(@desk))
  end

  private

  def resolve(text, name)
    @text = text
    @name = name
    @result = Collections::ListResolver.new.call(text)
    @lexemes = @result.lexemes
    return if @result.empty?

    memories = LexemeMemory.owned_by(Current.user).where(lexeme_id: @lexemes.map(&:id))
    @known_ids = memories.state_review.distinct.pluck(:lexeme_id).to_set
    @started_ids = memories.active.distinct.pluck(:lexeme_id).to_set
  end

  def submitted_text
    upload = params[:file]
    uploaded = upload.respond_to?(:read) ? upload.read.to_s.force_encoding("UTF-8").scrub : ""
    [params[:text].to_s, uploaded].compact_blank.join("\n")
  end

  def chosen_facets
    Array(params[:facets]).select { |facet| FACETS.include?(facet) }
  end

  def set_language
  end

  def set_desk
    @desk = Collection.desks_for(current_user).find_by(id: numeric_id(params[:id]))
    raise ActiveRecord::RecordNotFound if @desk.nil?
  end
end
