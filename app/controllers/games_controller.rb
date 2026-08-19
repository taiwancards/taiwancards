# frozen_string_literal: true

class GamesController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  GAMES = Huayu::GamesImporter::GAMES
  CATEGORIES = Huayu::GamesImporter::CATEGORIES

  def show
    @collection = Collection.find_by(kind: :games)
    @counts = counts
    @boards = GAMES.select { |name| @counts[name].to_i.positive? }
    @active = @boards.find { |name| name == params[:game] } || @boards.first
    @lexemes = ordered(@active)
    @sections = grouped(@lexemes)
  end

  private

  def scope
    return Lexeme.none if @collection.nil?

    @collection.lexemes.visible_to(current_user)
  end

  def counts
    scope.pluck(Arel.sql("lexemes.data -> 'game' ->> 'name'")).tally
  end

  def ordered(game)
    return [] if game.nil?

    scope
      .where("lexemes.data -> 'game' ->> 'name' = ?", game)
      .order(Arel.sql("collection_items.position"))
      .to_a
  end

  def grouped(rows)
    by_category = rows.group_by { |lexeme| lexeme.data.dig("game", "category") }
    CATEGORIES.filter_map { |category| [category, by_category[category]] if by_category[category].present? }
  end
end
