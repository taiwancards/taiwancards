# frozen_string_literal: true

module Huayu
  class GamesImporter < CuratedPageImporter
    PATH = AppData.path("huayu/games.json")
    SOURCE = "Taiwan games"
    COLLECTION = "Taiwan games"
    COLLECTION_KIND = :games
    COLLECTION_POSITION = 920
    GAMES = %w[mahjong mcr xiangqi go tabletop].freeze
    CATEGORIES = %w[
      game
      board
      piece
      equipment
      roles
      procedure
      meld
      call
      wait
      scoring
      pattern
      tactic
      opening
      endgame
      strategy
      rule
      rank
      talk
    ]
      .freeze

    private

    def accepted?(entry)
      super && GAMES.include?(entry["game"].to_s) && CATEGORIES.include?(entry["category"].to_s)
    end

    def payload(entry)
      {"game" => {"name" => entry["game"], "category" => entry["category"], "tier" => tier(entry)}}
    end
  end
end
