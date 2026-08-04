# frozen_string_literal: true

module Huayu
  class ZhuyinTrainer
    CHOICES = 4
    MASTERY_STREAK = 3
    FAST_MS = 2500

    BLOCKS = [
      {key: "labial", symbols: %w[ㄅ ㄆ ㄇ ㄈ]},
      {key: "alveolar", symbols: %w[ㄉ ㄊ ㄋ ㄌ]},
      {key: "velar", symbols: %w[ㄍ ㄎ ㄏ]},
      {key: "palatal", symbols: %w[ㄐ ㄑ ㄒ]},
      {key: "retroflex", symbols: %w[ㄓ ㄔ ㄕ ㄖ]},
      {key: "sibilant", symbols: %w[ㄗ ㄘ ㄙ]},
      {key: "medial", symbols: %w[ㄧ ㄨ ㄩ]},
      {key: "open", symbols: %w[ㄚ ㄛ ㄜ ㄝ]},
      {key: "diphthong", symbols: %w[ㄞ ㄟ ㄠ ㄡ]},
      {key: "nasal", symbols: %w[ㄢ ㄣ ㄤ ㄥ]},
      {key: "rhotic", symbols: %w[ㄦ]}
    ].freeze

    CONFUSABLE = {
      "ㄅ" => %w[ㄆ ㄉ ㄊ],
      "ㄆ" => %w[ㄅ ㄈ ㄊ],
      "ㄇ" => %w[ㄈ ㄋ ㄏ],
      "ㄈ" => %w[ㄇ ㄆ ㄏ],
      "ㄉ" => %w[ㄊ ㄅ ㄌ],
      "ㄊ" => %w[ㄉ ㄆ ㄍ],
      "ㄋ" => %w[ㄌ ㄇ ㄊ],
      "ㄌ" => %w[ㄋ ㄉ ㄖ],
      "ㄍ" => %w[ㄎ ㄏ ㄉ],
      "ㄎ" => %w[ㄍ ㄏ ㄊ],
      "ㄏ" => %w[ㄍ ㄎ ㄈ],
      "ㄐ" => %w[ㄑ ㄒ ㄓ],
      "ㄑ" => %w[ㄐ ㄒ ㄔ],
      "ㄒ" => %w[ㄐ ㄑ ㄕ],
      "ㄓ" => %w[ㄔ ㄕ ㄗ],
      "ㄔ" => %w[ㄓ ㄕ ㄘ],
      "ㄕ" => %w[ㄓ ㄔ ㄙ],
      "ㄖ" => %w[ㄌ ㄕ ㄗ],
      "ㄗ" => %w[ㄘ ㄙ ㄓ],
      "ㄘ" => %w[ㄗ ㄙ ㄔ],
      "ㄙ" => %w[ㄗ ㄘ ㄕ],
      "ㄧ" => %w[ㄨ ㄩ ㄦ],
      "ㄨ" => %w[ㄧ ㄩ ㄡ],
      "ㄩ" => %w[ㄨ ㄧ ㄥ],
      "ㄚ" => %w[ㄛ ㄜ ㄝ],
      "ㄛ" => %w[ㄚ ㄜ ㄡ],
      "ㄜ" => %w[ㄛ ㄝ ㄚ],
      "ㄝ" => %w[ㄜ ㄚ ㄞ],
      "ㄞ" => %w[ㄟ ㄠ ㄝ],
      "ㄟ" => %w[ㄞ ㄠ ㄡ],
      "ㄠ" => %w[ㄡ ㄞ ㄟ],
      "ㄡ" => %w[ㄠ ㄟ ㄨ],
      "ㄢ" => %w[ㄤ ㄣ ㄥ],
      "ㄣ" => %w[ㄥ ㄢ ㄤ],
      "ㄤ" => %w[ㄢ ㄥ ㄣ],
      "ㄥ" => %w[ㄣ ㄤ ㄢ],
      "ㄦ" => %w[ㄜ ㄝ ㄧ]
    }.freeze

    ALL = BLOCKS.flat_map { |block| block[:symbols] }.freeze

    GROUPS = {
      "initials" => %w[labial alveolar velar palatal retroflex sibilant],
      "finals" => %w[medial open diphthong nasal rhotic]
    }.freeze

    KEYS = BLOCKS.map { |block| block[:key] }.freeze

    ROWS = {
      "zhi_chi_shi" => %w[ㄓ ㄔ ㄕ],
      "zi_ci_si" => %w[ㄗ ㄘ ㄙ],
      "ji_qi_xi" => %w[ㄐ ㄑ ㄒ]
    }.freeze

    COLUMNS = {
      "zhi_zi_ji" => %w[ㄓ ㄗ ㄐ],
      "chi_ci_qi" => %w[ㄔ ㄘ ㄑ],
      "shi_si_xi" => %w[ㄕ ㄙ ㄒ]
    }.freeze

    SETS = ROWS.merge(COLUMNS).merge("all_nine" => (ROWS.values + COLUMNS.values).flatten.uniq).freeze

    def self.block_for(symbol) = BLOCKS.find { |block| block[:symbols].include?(symbol) }

    def self.blocks_in(group) = BLOCKS.select { |block| GROUPS.fetch(group.to_s, []).include?(block[:key]) }

    def initialize(mastery = {}, seed: nil, group: nil, block: nil, set: nil)
      @mastery = mastery.to_h { |key, value| [key.to_s, value.to_h.transform_keys(&:to_s)] }
      @rng = Random.new(seed || Random.new_seed)
      @group = GROUPS.key?(group.to_s) ? group.to_s : nil
      @block = KEYS.include?(block.to_s) ? block.to_s : nil
      @set = SETS.key?(set.to_s) ? set.to_s : nil
    end

    def group = @group

    def block = @block

    def set = @set

    def scoped? = [@set, @block, @group].any?(&:present?)

    def group_blocks
      return [{key: @set, symbols: SETS.fetch(@set)}] if @set
      return BLOCKS.select { |entry| entry[:key] == @block } if @block
      return BLOCKS if @group.nil?

      BLOCKS.select { |entry| GROUPS.fetch(@group).include?(entry[:key]) }
    end

    def blocks
      group_blocks.map { |block|
        done = block[:symbols].count { |symbol| mastered?(symbol) }
        {
          key: block[:key],
          symbols: block[:symbols],
          mastered: done,
          total: block[:symbols].size,
          complete: done == block[:symbols].size
        }
      }
    end

    def current_block
      blocks.find { |block| !block[:complete] } || blocks.last
    end

    def unlocked_symbols
      taught = blocks.take_while { |block| block[:complete] }.flat_map { |block| block[:symbols] }
      taught + current_block[:symbols]
    end

    def items(count: 10)
      pool = weighted_pool
      Array.new(count) { item_for(pool.sample(random: rng)) }
    end

    def item_for(symbol)
      others = distractors_for(symbol)
      {
        id: symbol,
        symbol:,
        clip: "/zhuyin/#{symbol}.opus",
        options: ([symbol] + others).shuffle(random: rng)
      }
    end

    def record(symbol, correct:, elapsed_ms: nil)
      entry = @mastery[symbol] ||= {"streak" => 0, "seen" => 0, "correct" => 0}
      entry["seen"] = entry["seen"].to_i + 1

      if correct
        entry["correct"] = entry["correct"].to_i + 1
        entry["streak"] = fast?(elapsed_ms) ? entry["streak"].to_i + 1 : entry["streak"].to_i
      else
        entry["streak"] = 0
      end

      @mastery
    end

    def mastery
      @mastery
    end

    def mastered?(symbol)
      @mastery.dig(symbol, "streak").to_i >= MASTERY_STREAK
    end

    def complete?
      scope_symbols.all? { |symbol| mastered?(symbol) }
    end

    def progress
      {mastered: scope_symbols.count { |symbol| mastered?(symbol) }, total: scope_symbols.size}
    end

    def scope_symbols
      group_blocks.flat_map { |block| block[:symbols] }
    end

    private

    attr_reader :rng

    def fast?(elapsed_ms)
      elapsed_ms.nil? || elapsed_ms.to_i <= FAST_MS
    end

    def weighted_pool
      symbols = unlocked_symbols
      weak = symbols.reject { |symbol| mastered?(symbol) }
      pool = weak.presence || symbols

      pool.shuffle(random: rng)
    end

    def distractors_for(symbol)
      inside = scoped? ? (scope_symbols - [symbol]).shuffle(random: rng) : []
      near = (CONFUSABLE[symbol] || []).select { |other| ALL.include?(other) }.shuffle(random: rng)
      picked = (inside + near).uniq.first(CHOICES - 1)
      picked += (ALL - [symbol] - picked).shuffle(random: rng).first(CHOICES - 1 - picked.size)
      picked.first(CHOICES - 1)
    end
  end
end
