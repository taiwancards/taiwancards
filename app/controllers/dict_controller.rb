# frozen_string_literal: true

class DictController < ApplicationController
  include Paginated
  include ProgressMarks

  PER_PAGE = 60
  KINDS = Lexeme::DICTIONARY_KINDS

  def index
    @levels = Huayu::TocflReadiness.new.levels
    @level = params[:level].presence
    @school = params[:school].presence_in(%w[1 2 3 4 5 6 7])
    @progress = params[:progress].presence_in(%w[new learning known])
    @sort = params[:sort].presence_in(%w[level freq]) || "level"
    @q = params[:q].to_s.strip

    scope = Lexeme.where(kind: KINDS).visible
    scope = scope.where(id: level_lexeme_ids(@level)) if @level
    scope = scope.where("lexemes.data ->> 'tbcl_grade' = ?", @school) if @school
    if @q.present?
      scope = scope.where(
        "lexemes.text ILIKE :q OR lexemes.meanings ->> 'en' ILIKE :q OR lexemes.meanings ->> 'ru' ILIKE :q",
        q: "%#{@q}%"
      )
    end

    scope = filter_progress(scope, @progress) if @progress

    ordered = @sort == "freq" ? scope.frequency_order : scope.curriculum_order
    page, = paginate(ordered, per_page: PER_PAGE, content_key: content_key)
    @entries = page.to_a
    load_progress(@entries)
  end

  def show
    @text = params[:text]
    lexeme = find_entry(@text)

    if lexeme.nil?
      neighbor = Lexeme.visible.find_by(kind: %i[character radical], text: @text)
      neighbor ||= Lexeme.visible.find_by(id: @text) if @text.match?(/\A\d+\z/)
      return redirect_to(lexeme_page_path(neighbor)) if neighbor

      return render(:missing, status: :not_found)
    end

    @profile = Huayu::WordProfile.new(lexeme)
    @sentence_profile = lexeme.sentence_profile
    @liangci = Liangci::Sidecar.new.call(lexeme)
    @thesaurus = Lexemes::Thesaurus.new.call(lexeme)
    @sketch = @profile.sketch
    @sketch_lexemes = resolve_collocates(@sketch)
    @revised = @profile.revised_senses(level: current_user&.level_grade)
  end

  def activate
    lexeme = find_entry(params[:text]) || raise(ActiveRecord::RecordNotFound)
    Lexemes::Activator.new.call(lexeme)
    redirect_to(lexeme_page_path(lexeme), notice: t("words.added"))
  end

  private

  def resolve_collocates(sketch)
    texts = sketch.relations.flat_map { |relation| relation.collocates.map(&:text) }.uniq
    return {} if texts.empty?

    Lexeme.visible.where(kind: %i[word collocation character], text: texts).index_by(&:text)
  end

  def content_key
    return nil if @progress.present?

    ["dict", @level, @school, @q].join("|")
  end

  def find_entry(text)
    Lexeme.visible.where(kind: KINDS, text: text).order(:kind).first
  end

  def level_lexeme_ids(level)
    collection = Collection.find_by(kind: :tocfl, level_tag: level)
    collection ? collection.collection_items.select(:lexeme_id) : Lexeme.none
  end

  def filter_progress(scope, progress)
    owned = LexemeMemory.owned_by(Current.user)
    case progress
    when "known"
      scope.where(id: owned.state_review.select(:lexeme_id))
    when "learning"
      scope.where(id: owned.active.where.not(state: %i[unseen review]).select(:lexeme_id))
    when "new"
      scope.where.not(id: owned.active.select(:lexeme_id))
    else
      scope
    end
  end
end
