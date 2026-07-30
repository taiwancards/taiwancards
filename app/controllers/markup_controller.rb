# frozen_string_literal: true

class MarkupController < ApplicationController
  layout "markup"

  before_action :require_admin
  before_action :set_locale
  before_action :set_mode

  def show
    @sentence = params[:id] ? sentences.find_by(id: numeric_id(params[:id])) : first_in(@mode)
    @sentence ||= first_in(other_mode)
    return render(:empty) if @sentence.nil?

    @words = breakdown_words(@sentence)
    @next_path = markup_next_path(@sentence)
    @counts = {done: sentences.where.not(meanings: {}).count, todo: sentences.where(meanings: {}).count}
  end

  def update
    sentence = sentences.find_by(id: numeric_id(params[:id])) || raise(ActiveRecord::RecordNotFound)
    following = markup_next_path(sentence)
    meanings = {"en" => params[:en].to_s.strip, "ru" => params[:ru].to_s.strip}.reject { |_, value| value.empty? }
    sentence.update!(meanings: meanings)
    Huayu::SentenceGlossStore.put(sentence.text, en: meanings["en"], ru: meanings["ru"])
    redirect_to(following)
  end

  def destroy
    sentence = sentences.find_by(id: numeric_id(params[:id])) || raise(ActiveRecord::RecordNotFound)
    following = markup_next_path(sentence)
    Huayu::SentenceGlossStore.put(sentence.text, en: nil, ru: nil)
    sentence.destroy!
    redirect_to(following)
  end

  private

  def set_locale
    code = params[:lang].presence || cookies[:locale].presence || I18n.default_locale.to_s
    @locale = I18n.available_locales.map(&:to_s).include?(code) ? code : I18n.default_locale.to_s
    I18n.locale = @locale
  end

  def set_mode
    @mode = params[:mode].to_s == "todo" ? "todo" : "done"
  end

  def other_mode
    @mode == "done" ? "todo" : "done"
  end

  def sentences
    Lexeme.where(kind: :sentence)
  end

  def scoped(mode)
    mode == "todo" ? sentences.where(meanings: {}) : sentences.where.not(meanings: {})
  end

  def first_in(mode)
    scoped(mode).order(:score, :id).first
  end

  def markup_next_path(sentence)
    following = scoped(@mode)
      .where("(lexemes.score, lexemes.id) > (?, ?)", sentence.score, sentence.id)
      .order(:score, :id)
      .first
    following ||= first_in(other_mode)
    return markup_path(lang: @locale, mode: @mode) if following.nil?

    markup_sentence_path(following, lang: @locale, mode: following.meanings.present? ? "done" : @mode)
  end

  def breakdown_words(sentence)
    units = sentence.data["segments"]
    units = Huayu::TextAnalyzer.new.segment(sentence.text) unless units.is_a?(Array) && units.any?

    lexemes = Lexeme.where(kind: %i[word character], text: units.uniq).index_by(&:text)
    units.map { |unit| [unit, lexemes[unit]&.meanings&.dig(@locale).to_s] }
  end
end
