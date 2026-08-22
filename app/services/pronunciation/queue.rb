# frozen_string_literal: true

module Pronunciation
  class Queue
    SIZE = 30
    POOL = 120
    MIN_WEAK = 3

    BEGINNER_POOL = 400

    REQUIRED = ([1, 2, 3, 4].map { |tone| "t:#{tone}" } +
      %w[ㄅ ㄆ ㄉ ㄊ ㄍ ㄎ ㄐ ㄑ ㄒ ㄓ ㄔ ㄕ ㄗ ㄘ ㄙ].map { |initial| "i:#{initial}" })
      .freeze

    WINDOW = 16

    PHRASES = 4
    PHRASE_EVERY = 7

    def initialize(
      user:,
      collection: nil,
      drills: Drills.instance,
      store: TemplateStore.instance,
      phrases: Phrases.instance
    )
      @user = user
      @collection = collection
      @drills = drills
      @store = store
      @phrases = phrases
    end

    def ids
      entries = candidates
      return [] if entries.empty?

      weave(diversify(entries, beginner? ? coverage(entries) : []))
    end

    def coverage(entries)
      needed = REQUIRED.to_set
      entries.each_with_object([]) do |entry, chosen|
        break chosen if needed.empty?

        hit = entry[:features].select { |feature| needed.include?(feature) }
        next if hit.empty?

        chosen << entry
        needed.subtract(hit)
      end
    end

    def beginner?
      @beginner = skills.empty? && studied_ids.empty? if @beginner.nil?
      @beginner
    end

    private

    def weave(picked)
      phrases = phrase_ids
      return picked if phrases.empty?

      phrases.each_with_index do |id, index|
        position = ((index + 1) * PHRASE_EVERY) + index
        break if position > picked.length

        picked.insert(position, id)
      end

      picked.first(SIZE)
    end

    def phrase_ids
      return [] if @collection || !@phrases.available?

      level = beginner? ? Phrases::BEGINNER_LEVEL : @phrases.level_for(@user)
      pool = @phrases.ids_up_to(level)
      return [] if pool.empty?

      (pool - attempted_ids).presence&.sample(PHRASES) || pool.sample(PHRASES)
    end

    def candidates
      weak = weak_ids
      ordered = (weak + fresh_ids).uniq.first(beginner? ? BEGINNER_POOL + SIZE : POOL)
      return [] if ordered.empty?

      by_id = Lexeme.where(id: ordered).index_by(&:id)
      entries = ordered.each_with_index.filter_map do |id, rank|
        lexeme = by_id[id] or next
        syllables = target_for(lexeme)
        next if syllables.empty?

        band = approval_band(syllables)
        next if beginner? && band.positive?

        {
          id:,
          tier: weak.include?(id) ? 0 : 1,
          band:,
          rank:,
          features: features(syllables)
        }
      end

      entries.sort_by { |entry| [entry[:tier], entry[:band], entry[:rank]] }
    end

    def weak_ids
      return [] if @user.nil? || weak_keys.empty?

      ids = PronunciationAttempt
        .where(user: @user, syllable_key: weak_keys)
        .order(created_at: :desc)
        .pluck(:lexeme_id)
        .uniq
      allowed = pronounceable.where(id: ids).pluck(:id).to_set
      ids.select { |id| allowed.include?(id) }.first(SIZE)
    end

    def weak_keys
      @weak_keys ||= skills.select { |skill| skill.ewma_overall.to_f < green_floor }.map(&:syllable_key)
    end

    def fresh_ids
      return beginner_ids if beginner?

      base.where.not(id: attempted_ids).order(:score).limit(POOL).pluck(:id)
    end

    def beginner_ids
      keys = @drills.available? ? @drills.approved_keys.to_a : []
      singles = keys.filter_map { |key| SyllableIndex.lookup(key) }
      words = pronounceable.where(kind: :word).curriculum_order.limit(BEGINNER_POOL).pluck(:id)

      (order_by_curriculum(singles) + words).uniq - attempted_ids
    end

    def order_by_curriculum(ids)
      return [] if ids.empty?

      Lexeme.where(id: ids).curriculum_order.pluck(:id)
    end

    def attempted_ids
      return [] if @user.nil?

      @attempted_ids ||= PronunciationAttempt.where(user: @user).distinct.pluck(:lexeme_id)
    end

    def studied_ids
      return [] if @user.nil?

      @studied_ids ||= LexemeMemory.where(user: @user).active.pluck(:lexeme_id)
    end

    def skills
      return [] if @user.nil?

      @skills ||= SyllableSkill.where(user: @user).where(n: MIN_WEAK..).to_a
    end

    def green_floor
      @green_floor ||= Verdict.new.bounds("overall")["green"]
    end

    def base
      return pronounceable if @collection || beginner?

      pronounceable.where(kind: :word)
    end

    def pronounceable
      scope = Lexeme.where(kind: %i[word character]).where("readings ->> 'pinyin' IS NOT NULL")
      scope = scope.where(id: @collection.lexemes.select(:id)) if @collection
      scope
    end

    def target_for(lexeme)
      Huayu::PronunciationTarget.new(lexeme).syllables
    rescue StandardError
      []
    end

    def approval_band(syllables)
      return 0 unless @drills.available?

      approved = syllables.count { |syllable| SyllableKey.candidates(syllable).any? { |key| @drills.approves?(key) } }
      return 0 if approved == syllables.length
      return 1 if approved.positive?

      2
    end

    def features(syllables)
      syllables.flat_map do |syllable|
        key = SyllableKey.candidates(syllable).first
        initial, _medial, final = Parts.split(syllable["zhuyin"])
        ["s:#{key}", "t:#{syllable["tone"]}", "i:#{initial}", "f:#{final}"].compact
      end
    end

    RECENT = 4

    def diversify(entries, seeds)
      state = {used: Hash.new(0), recent: [], picked: []}

      seeds.each { |entry| take(state, entry) }

      (entries - seeds).group_by { |entry| entry[:tier] }.sort_by(&:first).each do |_tier, group|
        pool = group.dup

        while state[:picked].length < SIZE && pool.any?
          take(state, pool.delete_at(best_index(pool, state[:used])))
        end
      end

      state[:picked]
    end

    def take(state, entry)
      state[:picked] << entry[:id]
      entry[:features].each { |feature| state[:used][feature] += 1 }
      state[:recent] << entry
      return if state[:recent].length <= RECENT

      state[:recent].shift[:features].each { |feature| state[:used][feature] -= 1 }
    end

    def best_index(pool, used)
      window = [pool.length, WINDOW].min
      (0...window).min_by { |index| [overlap(pool[index], used), index] }
    end

    def overlap(entry, used)
      entry[:features].sum { |feature| used[feature] }
    end
  end
end
