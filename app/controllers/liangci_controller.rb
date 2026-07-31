# frozen_string_literal: true

class LiangciController < ApplicationController
  NOUN_LIMIT = 60
  KINDS_PER_TEXT = 3
  EXAMPLE_LIMIT = 12
  GAME_OPTIONS = 4

  def index
    @entries = Lexeme.where(kind: :measure_word).order(:score).to_a
    @category = params[:category].presence_in(Liangci::CATEGORIES)
    @entries = @entries.select { |entry| entry.data["category"] == @category } if @category
    @by_category = @entries.group_by { |entry| entry.data["category"] }
    @counts = Lexeme.where(kind: :measure_word).group(Arel.sql("data->>'category'")).count
  end

  def show
    @entry = Lexeme.find_by(kind: :measure_word, text: params[:text])
    return render(:missing, status: :not_found) if @entry.nil?

    @nouns = nouns_for(@entry)
    @examples = examples_for(@entry, @nouns)
    @character = Lexeme.visible.find_by(kind: %i[character radical], text: @entry.text)
    @word = Lexeme.visible.where(kind: Lexeme::DICTIONARY_KINDS, text: @entry.text).order(:kind).first
  end

  def game
    @round = Liangci::GameRound.new(Current.user).call
  end

  private

  def nouns_for(entry)
    texts = Array(entry.data["nouns"])
    return [] if texts.empty?

    ids = ContentCache.fetch("liangci/nouns", entry.id, Lexeme.visibility_key) do
      Lexeme
        .visible
        .where(kind: %i[word character collocation], text: texts)
        .order(Arel.sql("lexemes.score NULLS LAST"))
        .limit(NOUN_LIMIT * KINDS_PER_TEXT)
        .pluck(:id, :text)
        .uniq(&:last)
        .first(NOUN_LIMIT)
        .map(&:first)
    end

    found = Lexeme.where(id: ids).index_by(&:id)
    ids.filter_map { |id| found[id] }
  end

  def examples_for(entry, nouns)
    pairs = nouns.map { |noun| [entry.text, noun.text] }
    Huayu::ClassifierExamples.new.for_pairs(pairs, limit: EXAMPLE_LIMIT)
  end
end
