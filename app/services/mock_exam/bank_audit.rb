# frozen_string_literal: true

require "csv"

module MockExam
  class BankAudit
    LIST = "huayu/tocfl_official.json"
    TABLE = "huayu/tocfl.csv"
    TAGS = {
      "Novice 1" => "Novice1",
      "Novice 2" => "Novice2",
      "Level 1" => "A1",
      "Level 2" => "A2",
      "Level 3" => "B1"
    }.freeze
    NAMES = %w[
      台北
      臺北
      台中
      臺中
      台南
      臺南
      高雄
      花蓮
      宜蘭
      新竹
      基隆
      屏東
      台東
      臺東
      南投
      嘉義
      淡水
      九份
      墾丁
      日月潭
      阿里山
      太魯閣
      士林
      西門
      永康
      龍山寺
      故宮
      小明
      小美
      小華
      小英
      大同
      中山
      中正
      民生
      忠孝
      和平
      文化
      光明
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
      許
      鄭
      謝
      郭
      洪
      曾
      廖
      賴
      徐
      周
      漢
      華
      東京
      首爾
      紐約
      巴黎
      倫敦
      泰國
      越南
      韓國
      英國
      法國
      德國
      加拿大
      澳洲
      新加坡
      馬來西亞
    ]
      .freeze
    BOUND = {"車" => "Novice1", "睡" => "Novice2", "折" => "A2"}.freeze
    PERFECT = "有"
    VERBS = /\AV(?!s)/

    Issue = Data.define(:level, :block, :kind, :detail) do
      def to_s = format("%-8s %-10s %-12s %s", level, block, kind, detail)
    end

    def initialize(guard: Huayu::MainlandGuard.new)
      @guard = guard
    end

    def call = Bank::LEVELS.flat_map { |level| audit(level) }

    def audit(level)
      allowed = cumulative(level)
      Bank.blocks(level).flat_map { |block| inspect_block(block, level, allowed) }
    end

    private

    def inspect_block(block, level, allowed)
      structure(block, level) + language(block, level, allowed)
    end

    def structure(block, level)
      issues = []
      choices = Bank.choices(level)
      issues << issue(level, block, :format, block.format) if Bank::FORMATS.exclude?(block.format)
      issues << issue(level, block, :empty, "no questions") if block.questions.empty?
      issues.concat(stimulus(block, level))

      block.questions.each_with_index do |question, index|
        label = "q#{index + 1}"
        if question.options.size != choices
          issues << issue(level, block, :choices, "#{label} has #{question.options.size}")
        end

        issues << issue(level, block, :duplicate, label) if question.options.uniq.size != question.options.size
        issues << issue(level, block, :blank_option, label) if question.options.any?(&:blank?)
        unless question.options.index(question.key) == question.answer
          issues << issue(level, block, :answer, "#{label} -> #{question.answer}")
        end

        issues.concat(prompt(block, level, question, label))
      end

      issues.concat(markers(block, level))
      issues
    end

    def stimulus(block, level)
      issues = []
      if block.sign?
        issues << issue(level, block, :sign, "missing") if block.sign.nil?
        issues << issue(level, block, :sign, "no lines") if block.sign && block.sign.lines.empty?
      elsif block.text.blank?
        issues << issue(level, block, :stimulus, "empty")
      end

      issues << issue(level, block, :translation, "stimulus en") if block.names["en"].blank?
      issues << issue(level, block, :translation, "stimulus ru") if block.names["ru"].blank?
      issues
    end

    def prompt(block, level, question, label)
      issues = []
      if block.format == "cloze" || block.format == "paragraph"
        issues << issue(level, block, :prompt, "#{label} must not ask") if question.ask.present?
        return issues
      end

      issues << issue(level, block, :prompt, "#{label} missing") if question.ask.blank?
      issues << issue(level, block, :translation, "#{label} en") if question.names["en"].blank?
      issues << issue(level, block, :translation, "#{label} ru") if question.names["ru"].blank?
      issues
    end

    def markers(block, level)
      issues = []
      slots = block.text.scan(/[①-⑥]/).size
      gaps = block.text.scan(Bank::GAP).size

      case block.format
      when "cloze"
        issues << issue(level, block, :slots, "#{slots} for #{block.size} questions") if slots != block.size
      when "paragraph"
        issues << issue(level, block, :gap, "#{gaps} gaps") if gaps != 1
        issues << issue(level, block, :gap, "one question only") if block.size != 1
      else
        issues << issue(level, block, :slots, "unexpected marker") if slots.positive? || gaps.positive?
      end

      issues
    end

    def language(block, level, allowed)
      texts(block).flat_map do |text|
        script(block, level, text) + vocabulary(block, level, allowed, text) + register(block, level, allowed, text)
      end
    end

    def texts(block)
      list = [block.text]
      list += [block.sign.title, block.sign.foot, *block.sign.lines] if block.sign
      block.questions.each { |question|
        list << question.ask
        list.concat(question.options)
      }
      list.compact_blank
    end

    def script(block, level, text)
      issues = []
      issues << issue(level, block, :simplified, text) if simplified?(text)
      offender = @guard.offender(text)
      issues << issue(level, block, :mainland, "#{offender} in #{text}") if offender
      issues
    end

    def vocabulary(block, level, allowed, text)
      cover(text, allowed).missing.map { |char| issue(level, block, :vocabulary, "#{char} in #{excerpt(text)}") }
    end

    def register(block, level, allowed, text)
      cover(text, allowed).tokens.each_cons(2).filter_map do |left, right|
        next unless left == PERFECT && verb?(right)

        issue(level, block, :register, "#{left}#{right} in #{excerpt(text)}")
      end
    end

    def cover(text, allowed)
      @covers ||= {}
      cover = @covers[allowed.object_id] ||= WordCover.new(allowed + NAMES.to_set)
      cover.call(text)
    end

    def excerpt(text) = text.tr("\n", " ")[0, 40]

    def simplified?(text)
      return false unless Huayu::SimpToTrad.available?

      table = Huayu::SimpToTrad.table
      text.each_char.any? do |char|
        swap = table[char]
        swap.present? && swap != char && traditional.exclude?(char)
      end
    end

    def traditional
      @traditional ||= (entries.keys.join + NAMES.join).chars.to_set
    end

    def verb?(token) = parts[token].to_s.split("/").any? { |tag| tag.match?(VERBS) }

    def cumulative(level)
      @cumulative ||= {}
      @cumulative[level] ||= begin
        stop = Bank::LEVELS.index(level)
        wanted = Bank::LEVELS.first(stop + 1)
        words = entries.select { |_word, tag| wanted.include?(tag) }.keys
        bound = BOUND.select { |_form, tag| wanted.include?(tag) }.keys
        (words + bound).to_set
      end
    end

    def entries
      @entries ||= begin
        path = AppData.path(LIST)
        rows = path.exist? ? JSON.parse(path.read) : []
        rows.each_with_object({}) do |row, memo|
          tag = TAGS[row["level"]]
          next if tag.nil?

          word = row["traditional"]
          memo[word] = tag if memo[word].nil? || Bank::LEVELS.index(tag) < Bank::LEVELS.index(memo[word])
        end
      end
    end

    def parts
      @parts ||= begin
        path = AppData.path(TABLE)
        table = {}
        if path.exist?
          CSV.foreach(path, headers: true) do |row|
            row["Traditional"].to_s.split(%r{[/／]}).each { |form| table[form.strip] = row["POS"].to_s }
          end
        end

        table
      end
    end

    def issue(level, block, kind, detail) = Issue.new(level: level, block: block.id, kind: kind, detail: detail)
  end
end
