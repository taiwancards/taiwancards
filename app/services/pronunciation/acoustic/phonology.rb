# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Phonology
      INITIALS = %w[zh ch sh b p m f d t n l g k h j q x r z c s].freeze

      ASPIRATED = %w[p t k q ch c].freeze

      SONORANTS = %w[m n l r].freeze

      ASPIRATION_PAIRS = {
        "b" => "p",
        "p" => "b",
        "d" => "t",
        "t" => "d",
        "g" => "k",
        "k" => "g",
        "j" => "q",
        "q" => "j",
        "zh" => "ch",
        "ch" => "zh",
        "z" => "c",
        "c" => "z"
      }.freeze

      APICAL_DENTAL = %w[z c s].freeze

      APICAL_RETROFLEX = %w[zh ch sh r].freeze

      SIBILANT_SERIES = {
        "z" => :dental,
        "c" => :dental,
        "s" => :dental,
        "zh" => :retroflex,
        "ch" => :retroflex,
        "sh" => :retroflex,
        "r" => :retroflex,
        "j" => :alveolo_palatal,
        "q" => :alveolo_palatal,
        "x" => :alveolo_palatal
      }.freeze

      SERIES_COUNTERPARTS = {
        "z" => %w[zh j],
        "c" => %w[ch q],
        "s" => %w[sh x],
        "zh" => %w[z j],
        "ch" => %w[c q],
        "sh" => %w[s x],
        "j" => %w[z zh],
        "q" => %w[c ch],
        "x" => %w[s sh]
      }.freeze

      INITIAL_IPA = {
        "b" => "p",
        "p" => "pʰ",
        "m" => "m",
        "f" => "f",
        "d" => "t",
        "t" => "tʰ",
        "n" => "n",
        "l" => "l",
        "g" => "k",
        "k" => "kʰ",
        "h" => "h",
        "j" => "tɕ",
        "q" => "tɕʰ",
        "x" => "ɕ",
        "zh" => "ʈʂ",
        "ch" => "ʈʂʰ",
        "sh" => "ʂ",
        "r" => "ʐ",
        "z" => "ts",
        "c" => "tsʰ",
        "s" => "s",
        "" => ""
      }.freeze

      module_function

      def obstruent?(initial)
        text = initial.to_s
        INITIALS.include?(text) && !SONORANTS.include?(text)
      end

      def expand(syl)
        s = syl.downcase.tr("ü", "v")

        s = case s
        when /\Ayu(.*)\z/
          "v#{$1}"
        when /\Ayi(.*)\z/
          "i#{$1}"
        when /\Ay(.+)\z/
          "i#{$1}"
        when /\Awu\z/
          "u"
        when /\Aw(.+)\z/
          "u#{$1}"
        else
          s
        end

        s = s.sub(/\A(j|q|x)u/) { "#{$1}v" }

        s
      end

      def expand_final(final, has_initial)
        return final unless has_initial

        case final
        when "iu"
          "iou"
        when "ui"
          "uei"
        when "un"
          "uen"
        when "vn"
          "ven"
        else
          final
        end
      end

      def analyze(syllable)
        s = expand(syllable)

        initial = INITIALS.find { |i| s.start_with?(i) && s.length > i.length } || ""
        initial = "" if s == initial

        rest = s[initial.length..] || ""
        final = expand_final(rest, !initial.empty?)

        medial = ""
        body = final
        if final.length > 1 && %w[i u v].include?(final[0]) && final[1..].match?(/\A[aeiouv]/)
          medial = final[0]
          body = final[1..]
        end

        coda = if body.end_with?("ng")
          "ng"
        elsif body.end_with?("n")
          "n"
        elsif body.length > 1 && %w[i o u].include?(body[-1])
          body[-1]
        elsif body == "er"
          "r"
        else
          ""
        end

        nucleus = coda.empty? ? body : body[0...(body.length - coda.length)]
        nucleus = body if nucleus.empty?

        {
          syllable: syllable,
          initial: initial,
          initial_ipa: INITIAL_IPA[initial] || initial,
          aspirated: ASPIRATED.include?(initial),
          sibilant: SIBILANT_SERIES[initial],
          medial: medial,
          nucleus: nucleus,
          apical: apical(initial, final),
          coda: coda,
          nasal_coda: %w[n ng].include?(coda),
          final: final
        }
      end

      def apical(initial, final)
        return nil unless final == "i"
        return :dental if APICAL_DENTAL.include?(initial)

        :retroflex if APICAL_RETROFLEX.include?(initial)
      end

      def neighbors(syllable, existing)
        a = analyze(syllable)
        out = []

        if (pair = ASPIRATION_PAIRS[a[:initial]])
          out << (pair + a[:final])
        end

        (SERIES_COUNTERPARTS[a[:initial]] || []).each { |c| out << (c + a[:final]) }

        if a[:coda] == "n"
          out << (a[:initial] + a[:final] + "g")
        elsif a[:coda] == "ng"
          out << (a[:initial] + a[:final][0...-1])
        end

        case a[:initial]
        when "n"
          out << ("l" + a[:final])
        when "l"
          out << ("n" + a[:final])
        when "f"
          out << ("h" + a[:final])
        when "h"
          out << ("f" + a[:final])
        end

        out
          .map { |x| x.tr("v", "ü") }
          .map { |x| contract(x) }
          .uniq
          .select { |x| existing.include?(x) && x != syllable }
      end

      def contract(s)
        t = s.dup
        t = t.sub(/([a-z]+)iou\z/) { "#{$1}iu" }
        t = t.sub(/([a-z]+)uei\z/) { "#{$1}ui" }
        t = t.sub(/([a-z]+)uen\z/) { "#{$1}un" }
        t
      end
    end
  end
end
