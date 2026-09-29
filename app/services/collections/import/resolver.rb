# frozen_string_literal: true

module Collections
  module Import
    class Resolver
      KINDS = %i[word character collocation].freeze
      MAX_SPELLINGS = 16
      TAIWAN_FORMS = %r{[/／、]}
      NOT_TAIWAN = TWFilter::Tables.set("converted_orthography.txt")
      COMMON = TWFilter::Tables.set("moe_common.txt")

      Entry = Data.define(:row, :lexeme, :from)
      Choice = Data.define(:row, :options)
      ChinaTerm = Data.define(:row, :term, :offender, :taiwan)
      Result = Data.define(:ready, :converted, :choices, :china, :missing, :duplicates, :covered_ids) do
        def ready_ids = ready.map { |entry| entry.lexeme.id }

        def fresh_ids = ready_ids.reject { |id| covered_ids.include?(id) }
      end

      def initialize(user)
        @user = user
      end

      def call(rows)
        @lexicon = lookup(spellings(rows))
        @seen = Set.new
        @offenders = {}
        @taiwan = {}
        buckets = {ready: [], converted: [], choices: [], china: [], missing: [], duplicates: []}
        rows.each { |row| place(row, buckets) }
        covered = Collections::Coverage.new(@user).covered_ids(buckets[:ready].map { |entry| entry.lexeme.id })
        Result.new(**buckets, covered_ids: covered)
      end

      private

      def place(row, buckets)
        direct = row.candidates.filter_map { |text| @lexicon[text] }.find { |lexeme| taiwan_spelling?(lexeme.text) }
        converted = taiwanese(row.candidates.flat_map { |text| spelled(text) }.filter_map { |text| @lexicon[text] })
        found = narrowed([direct, *converted].compact.uniq, row.pinyin)
        return offer(row, found, buckets) if found.many?
        return settle(row, found.first, (row.candidates.first unless found.first == direct), buckets) if found.one?

        term = china_term(row, traditional(row.candidates.first))
        term ? buckets[:china] << term : buckets[:missing] << row
      end

      def settle(row, lexeme, from, buckets)
        term = china_term(row, lexeme.text)
        return buckets[:china] << term if term
        return buckets[:duplicates] << row unless @seen.add?(lexeme.id)

        entry = Entry.new(row:, lexeme:, from:)
        buckets[:ready] << entry
        buckets[:converted] << entry if from
      end

      def offer(row, found, buckets)
        allowed = found.reject { |lexeme| offender(lexeme.text) }
        return settle(row, allowed.first, row.candidates.first, buckets) if allowed.one?
        return buckets[:missing] << row if allowed.empty?

        buckets[:choices] << Choice.new(row:, options: allowed)
      end

      def china_term(row, text)
        found = offender(text)
        found && ChinaTerm.new(row:, term: text, offender: found, taiwan: taiwan_options(text, found))
      end

      def offender(text)
        @offenders.fetch(text) do
          verdict = Huayu::TextGate.call(text)
          found = verdict.reason == :china ? verdict.offender.to_s : Huayu::ChinaGuard.soft_offender(text)
          @offenders[text] = found.presence
        end
      end

      def taiwan_options(text, offender)
        @taiwan[[text, offender]] ||= begin
          form = TWFilter::Checks::Lexicon.taiwan_form(offender).to_s
          spellings = form.split(TAIWAN_FORMS).map(&:strip).compact_blank.map { |taiwan| text.sub(offender, taiwan) }
          known = lookup(spellings)
          spellings.map { |spelling| known[spelling] || spelling }
        end
      end

      def narrowed(found, pinyin)
        return found if found.size < 2 || pinyin.blank?

        wanted = sound(pinyin)
        exact = found.select { |lexeme| readings(lexeme).any? { |reading| sound(reading) == wanted } }
        return exact if exact.any?

        loose = Huayu::ReadingForms.plain_pinyin(pinyin)
        matching = found.select { |lexeme|
          readings(lexeme).any? { |reading| Huayu::ReadingForms.plain_pinyin(reading) == loose }
        }
        matching.presence || found
      end

      def heard?(lexeme, pinyin)
        return true if pinyin.blank?

        wanted = sound(pinyin)
        readings(lexeme).any? { |reading| sound(reading) == wanted }
      end

      def taiwanese(found)
        standard = found.uniq.select { |lexeme| taiwan_spelling?(lexeme.text) }
        common = standard.select { |lexeme| lexeme.text.each_char.all? { |char| COMMON.include?(char) } }.presence ||
          standard
        tier = common.map(&:tier).min
        common.select { |lexeme| lexeme.tier == tier }
      end

      def taiwan_spelling?(text)
        text.each_char.none? { |char| NOT_TAIWAN.include?(char) || Huayu::SimpToTrad::TAIWAN_VARIANTS.key?(char) }
      end

      def readings(lexeme) = lexeme.reading_set.filter_map { |reading| reading["pinyin"].presence }

      def sound(pinyin)
        text = pinyin.to_s.downcase.gsub("u:", "ü").tr("v", "ü")
        numbered = text.match?(/\d/) ? text.gsub(/[^a-zü1-5]/, "") : Huayu::ReadingForms.numbered_pinyin(text)
        numbered.delete("05")
      end

      def traditional(text) = Huayu::TraditionalOnly.to_traditional(text)

      def spellings(rows)
        rows.flat_map { |row| row.candidates.flat_map { |text| [text, *spelled(text)] } }.uniq
      end

      def spelled(text)
        options = text.each_char.map { |char| Huayu::SimpToTrad.options(char) }
        return [] if options.each_with_index.all? { |choices, index| choices == [text[index]] }

        options.reduce([""]) { |built, choices|
          built.product(choices).map(&:join).first(MAX_SPELLINGS)
        } -
          [text]
      end

      def lookup(texts)
        return {} if texts.empty?

        rank = KINDS.each_with_index.to_h { |kind, index| [kind.to_s, index] }
        Lexeme
          .visible_to(@user)
          .where(kind: KINDS, text: texts)
          .to_a
          .group_by(&:text)
          .transform_values { |lexemes| lexemes.min_by { |lexeme| rank.fetch(lexeme.kind) } }
      end
    end
  end
end
