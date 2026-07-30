# frozen_string_literal: true

module Placement
  class ItemBank
    POOL_SIZE = 60
    CHOICES = 4
    SENTENCE_POOL = 24
    FOIL_ODDS = 0.4

    TRADITIONAL_PAIRS = {
      "學" => "学",
      "灣" => "湾",
      "麼" => "么",
      "醫" => "医",
      "買" => "买",
      "讀" => "读",
      "覺" => "觉",
      "邊" => "边",
      "歲" => "岁",
      "鐵" => "铁"
    }.freeze

    GRAMMAR = [
      {grade: 1, prompt: "我{}學生", answer: "是", choices: %w[是 有 在 很]},
      {grade: 1, prompt: "他{}台北", answer: "在", choices: %w[在 是 到 從]},
      {grade: 2, prompt: "我吃{}飯了", answer: "過", choices: %w[過 著 的 得]},
      {grade: 2, prompt: "這杯咖啡{}好喝", answer: "很", choices: %w[很 太 更 最]},
      {grade: 3, prompt: "他跑{}很快", answer: "得", choices: %w[得 的 地 了]},
      {grade: 3, prompt: "我{}書放在桌上", answer: "把", choices: %w[把 被 讓 給]},
      {grade: 4, prompt: "錢{}他拿走了", answer: "被", choices: %w[被 把 對 跟]},
      {grade: 4, prompt: "他一到{}打電話給我", answer: "就", choices: %w[就 才 也 還]},
      {
        grade: 5,
        prompt: "{}天氣不好，我們還是去了",
        answer: "雖然",
        choices: %w[雖然 因為 如果 除非]
      },
      {grade: 5, prompt: "越吃{}辣", answer: "越", choices: %w[越 更 最 太]},
      {grade: 6, prompt: "他{}沒來，而且沒說一聲", answer: "不但", choices: %w[不但 不管 不然 不過]},
      {grade: 6, prompt: "這件事{}我來說並不難", answer: "對", choices: %w[對 跟 給 從]}
    ].freeze

    TAIWAN_USAGE = [
      {grade: 2, prompt: "謝謝", answer: "不會", choices: %w[不會 不客氣 沒事兒 別客氣]},
      {grade: 2, prompt: "地下鐵路系統", answer: "捷運", choices: %w[捷運 地鐵 輕軌 電車]},
      {grade: 3, prompt: "計費的載客汽車", answer: "計程車", choices: %w[計程車 出租車 的士 打車]},
      {
        grade: 3,
        prompt: "馬鈴薯做成的零食",
        answer: "洋芋片",
        choices: %w[洋芋片 薯片 土豆片 薯條]
      },
      {grade: 4, prompt: "在店裡結束購買", answer: "結帳", choices: %w[結帳 買單 付錢 收錢]},
      {grade: 4, prompt: "電子發票的儲存工具", answer: "載具", choices: %w[載具 發票夾 收據 條碼]}
    ].freeze

    def initialize(rng: Random.new)
      @rng = rng
    end

    def item_for(axis:, grade:, exclude_ids: [])
      case axis
      when "listening"
        listening_item(grade, exclude_ids)
      when "tones"
        tone_item(grade, exclude_ids)
      when "syllables"
        syllable_item(grade, exclude_ids)
      when "script"
        script_item(grade, exclude_ids)
      when "characters"
        character_item(grade, exclude_ids)
      when "vocab_size"
        vocab_size_item(grade, exclude_ids)
      when "grammar"
        fixed_item("grammar", GRAMMAR, grade)
      when "taiwan"
        fixed_item("taiwan", TAIWAN_USAGE, grade)
      when "sentences"
        sentence_item(grade)
      when "traditional"
        traditional_item(grade)
      else
        lexis_item(grade, exclude_ids)
      end
    end

    private

    def build(axis, grade, prompt, choices, answer, lexeme_id: nil, hint: nil, audio: nil, format: "choice")
      {
        "id" => "#{axis}-#{lexeme_id || SecureRandom.hex(4)}",
        "axis" => axis,
        "format" => format,
        "grade" => grade,
        "difficulty" => Ability.difficulty_of(grade),
        "prompt" => prompt,
        "hint" => hint,
        "audio" => audio,
        "choices" => choices,
        "answer" => answer,
        "lexeme_id" => lexeme_id
      }
    end

    def pool(grade, kinds: %i[character word])
      Lexeme
        .unrestricted
        .where(kind: kinds)
        .at_level(grade)
        .where("lexemes.meanings ->> ? IS NOT NULL OR lexemes.meanings ->> 'en' IS NOT NULL", I18n.locale.to_s)
        .curriculum_order
        .limit(POOL_SIZE)
        .to_a
    end

    def choose(candidates, exclude_ids)
      candidates.reject { |lexeme| exclude_ids.include?(lexeme.id) }.presence&.sample(random: @rng)
    end

    def meaning_choices(candidates, target)
      answer = target.meaning(I18n.locale)
      return nil if answer.blank?

      distractors = candidates
        .reject { |other| other.id == target.id || other.meaning(I18n.locale).blank? }
        .map { |other| other.meaning(I18n.locale) }
        .uniq
        .reject { |text| text == answer }
        .sample(CHOICES - 1, random: @rng)
      return nil if distractors.length < CHOICES - 1

      choices = ([answer] + distractors).shuffle(random: @rng)
      [choices, choices.index(answer)]
    end

    def lexis_item(grade, exclude_ids)
      candidates = pool(grade)
      target = choose(candidates, exclude_ids) || return
      choices, answer = meaning_choices(candidates, target) || return

      build("lexis", grade, target.text, choices, answer, lexeme_id: target.id, hint: target.reading("zhuyin"))
    end

    def character_item(grade, exclude_ids)
      candidates = pool(grade, kinds: %i[character])
      target = choose(candidates, exclude_ids) || return
      choices, answer = meaning_choices(candidates, target) || return

      build("characters", grade, target.text, choices, answer, lexeme_id: target.id)
    end

    def script_item(grade, exclude_ids)
      candidates = pool(grade, kinds: %i[character])
      target = choose(candidates, exclude_ids) || return
      reading = target.reading("zhuyin").presence || return

      distractors = candidates
        .reject { |other| other.id == target.id }
        .map(&:text)
        .uniq
        .sample(CHOICES - 1, random: @rng)
      return if distractors.length < CHOICES - 1

      choices = ([target.text] + distractors).shuffle(random: @rng)
      build("script", grade, reading, choices, choices.index(target.text), lexeme_id: target.id)
    end

    def vocab_size_item(grade, exclude_ids)
      foil = @rng.rand < FOIL_ODDS
      candidates = pool(grade)
      target = choose(candidates, exclude_ids) || return
      choices = %w[yes no]

      return build("vocab_size", grade, invent(candidates, target), choices, 1, format: "yesno") if foil

      build("vocab_size", grade, target.text, choices, 0, lexeme_id: target.id, format: "yesno")
    end

    def invent(candidates, target)
      donors = candidates.reject { |other| other.id == target.id }.map(&:text).select { |text| text.length > 1 }
      donor = donors.sample(random: @rng)
      return "#{target.text[0]}#{donor[-1]}" if donor && target.text.length > 1

      target.text.chars.rotate.join
    end

    def listening_item(grade, exclude_ids)
      candidates = pool(grade)
      target = candidates
        .reject { |lexeme| exclude_ids.include?(lexeme.id) }
        .find { |lexeme| Huayu::MoeAudio.for(lexeme.text, zhuyin: lexeme.reading("zhuyin")) }
      return if target.nil?

      clip = Huayu::MoeAudio.for(target.text, zhuyin: target.reading("zhuyin"))
      choices, answer = meaning_choices(candidates, target) || return

      build(
        "listening",
        grade,
        nil,
        choices,
        answer,
        lexeme_id: target.id,
        audio: {"url" => Huayu::MoeAudio.clip_url(clip.scope, clip.id), "stop_ms" => clip.head_ms}
      )
    end

    def voiced(grade, exclude_ids)
      pool(grade, kinds: %i[character])
        .reject { |lexeme| exclude_ids.include?(lexeme.id) }
        .find { |lexeme| Huayu::CnsVoice.covers?(lexeme.reading("zhuyin")) }
    end

    def tone_item(grade, exclude_ids)
      target = voiced(grade, exclude_ids) || return
      tone = Huayu::ToneDrill.tone_of(target.reading("zhuyin")) || return
      clip = Huayu::CnsVoice.alternating(target.reading("zhuyin"), @rng.rand(2))
      choices = Huayu::ToneDrill::TONES.map(&:to_s)

      build(
        "tones",
        grade,
        nil,
        choices,
        choices.index(tone.to_s),
        lexeme_id: target.id,
        audio: {"url" => Huayu::CnsVoice.clip_url(clip.voice, clip.key)}
      )
    end

    def syllable_item(grade, exclude_ids)
      target = voiced(grade, exclude_ids) || return
      answer = target.reading("zhuyin")
      rivals = Huayu::Zhuyin
        .segment(Huayu::ReadingForms.plain_pinyin(target.reading("pinyin").to_s))
        .presence
      return if rivals.nil?

      neighbours = neighbouring_readings(grade, answer)
      return if neighbours.length < CHOICES - 1

      choices = ([answer] + neighbours.sample(CHOICES - 1, random: @rng)).shuffle(random: @rng)
      clip = Huayu::CnsVoice.alternating(answer, @rng.rand(2))

      build(
        "syllables",
        grade,
        nil,
        choices,
        choices.index(answer),
        lexeme_id: target.id,
        audio: {"url" => Huayu::CnsVoice.clip_url(clip.voice, clip.key)}
      )
    end

    def neighbouring_readings(grade, answer)
      pool(grade, kinds: %i[character])
        .filter_map { |lexeme| lexeme.reading("zhuyin").presence }
        .uniq
        .reject { |reading| reading == answer }
        .sort_by { |reading| -common_prefix(reading, answer) }
        .first(CHOICES * 2)
    end

    def common_prefix(left, right)
      length = [left.length, right.length].min
      (0...length).find { |index| left[index] != right[index] } || length
    end

    def fixed_item(axis, bank, grade)
      row = bank.select { |entry| entry[:grade] == grade }.sample(random: @rng) ||
        bank.min_by { |entry| (entry[:grade] - grade).abs }
      return if row.nil?

      choices = row[:choices].shuffle(random: @rng)
      build(axis, row[:grade], row[:prompt], choices, choices.index(row[:answer]))
    end

    def sentence_item(grade)
      scheme = SentenceProfile::SCHEMES.fetch("tocfl")
      rows = SentenceProfile
        .where(scheme[:index] => ..grade)
        .where(scheme[:exact] => true)
        .order(:difficulty)
        .limit(SENTENCE_POOL)
        .includes(:lexeme)
        .filter_map(&:lexeme)
        .select { |lexeme| lexeme.meaning(I18n.locale).present? }
      return if rows.length < CHOICES

      target = rows.sample(random: @rng)
      distractors = rows.reject { |other| other.id == target.id }.sample(CHOICES - 1, random: @rng)
      choices = ([target] + distractors).map { |lexeme| lexeme.meaning(I18n.locale) }.shuffle(random: @rng)

      build("sentences", grade, target.text, choices, choices.index(target.meaning(I18n.locale)), lexeme_id: target.id)
    end

    def traditional_item(grade)
      traditional, simplified = TRADITIONAL_PAIRS.to_a.sample(random: @rng)
      others = (TRADITIONAL_PAIRS.keys - [traditional]).sample(CHOICES - 1, random: @rng)
      choices = ([traditional] + others).shuffle(random: @rng)

      build("traditional", grade, simplified, choices, choices.index(traditional))
    end
  end
end
