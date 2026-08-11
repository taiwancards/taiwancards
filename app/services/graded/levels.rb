# frozen_string_literal: true

module Graded
  class Levels
    PATH = "huayu/reader/levels.json"
    NAMES = %w[
      臺灣
      台灣
      臺北
      台北
      臺南
      台南
      臺中
      台中
      臺東
      台東
      高雄
      花蓮
      宜蘭
      新竹
      基隆
      屏東
      嘉義
      淡水
      九份
      墾丁
      阿里山
      臺鐵
      台鐵
      捷運
      小明
      小美
      小華
      小安
      王
      李
      陳
      林
      張
      黃
      吳
      劉
      蔡
      楊
    ]
      .freeze

    Tier = Data.define(:id, :kind, :size, :items, :allowed, :cover) do
      def chars? = kind == "chars"

      def label = chars? ? "#{size} characters" : "#{size} words"
    end

    class << self
      def all = payload[:tiers]

      def ids = all.map(&:id)

      def find(id) = payload[:by_id][id.to_s]

      def reset! = @payload = nil

      private

      def payload
        @payload ||= begin
          raw = read
          tiers = raw.fetch("tiers", []).map { |tier| build(tier, raw) }
          {tiers: tiers, by_id: tiers.index_by(&:id)}
        end
      end

      def build(tier, raw)
        kind = tier.fetch("kind")
        size = tier.fetch("size").to_i
        items = raw.fetch(kind, []).first(size)
        allowed = items.to_set + NAMES
        Tier.new(
          id: tier.fetch("id"),
          kind: kind,
          size: size,
          items: items,
          allowed: allowed,
          cover: WordCover.new(allowed)
        )
      end

      def read
        path = AppData.path(PATH)
        path.exist? ? JSON.parse(path.read) : {}
      end
    end
  end
end
