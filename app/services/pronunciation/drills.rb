# frozen_string_literal: true

module Pronunciation
  class Drills
    class << self
      def instance
        store = TemplateStore.instance
        @instance = nil if @instance && @instance.root != store.root
        @instance ||= new(store.root)
      end

      def reset!
        @instance = nil
      end
    end

    def initialize(root)
      @root = root
    end

    attr_reader :root

    GROUPS = {
      "tones" => %w[tones tone_1 tone_2 tone_3 tone_4 tone_5],
      "initials" => %w[
        aspiration
        sibilants
        initials_plosive
        initials_affricate
        initials_fricative
        initials_nasal_lateral
      ],
      "finals" => %w[vowel_a vowel_o vowel_e vowel_i vowel_u vowel_v coda_a coda_e]
    }.freeze

    SHORT = {
      "tones" => "1–4",
      "tone_1" => "1",
      "tone_2" => "2",
      "tone_3" => "3",
      "tone_4" => "4",
      "tone_5" => "˙",
      "aspiration" => "ㄅ／ㄆ",
      "sibilants" => "ㄗ／ㄓ／ㄐ",
      "initials_plosive" => "ㄅㄉㄍ",
      "initials_affricate" => "ㄗㄓㄐ",
      "initials_fricative" => "ㄈㄙㄒ",
      "initials_nasal_lateral" => "ㄇㄋㄌ",
      "vowel_a" => "ㄚ",
      "vowel_o" => "ㄛ",
      "vowel_e" => "ㄜ",
      "vowel_i" => "ㄧ",
      "vowel_u" => "ㄨ",
      "vowel_v" => "ㄩ",
      "coda_a" => "ㄢ／ㄤ",
      "coda_e" => "ㄣ／ㄥ"
    }.freeze

    def data
      return @data if @data

      path = File.join(@root, "drills.json")
      return {"sections" => []} unless File.exist?(path)

      @data = JSON.parse(File.read(path))
    end

    def grouped
      by_id = solid_sections.index_by { |section| section["id"] }

      GROUPS.filter_map do |group, ids|
        members = ids.filter_map { |id| by_id[id] }
        next if members.empty?

        [group, members]
      end
    end

    def group_of(id) = GROUPS.find { |_, ids| ids.include?(id) }&.first

    def short(id) = SHORT[id] || id

    def available? = sections.any?

    def sections = data["sections"] || []

    def section(id) = sections.find { |s| s["id"] == id }

    def solid_sections = sections.reject { |s| s["thin"] }

    def thin_sections = sections.select { |s| s["thin"] }

    def approved_keys
      @approved_keys ||= sections.flat_map { |s| (s["pairs"] || s["sets"] || [s["keys"]]).flatten }.compact.uniq.to_set
    end

    def approves?(key) = approved_keys.include?(key)

    def keys_for(id)
      s = section(id)
      return [] unless s

      (s["pairs"] || s["sets"] || [s["keys"]]).flatten.compact
    end

    def items_for(id)
      s = section(id)
      return [] unless s

      s["pairs"] || s["sets"] || Array(s["keys"]).map { |k| [k] }
    end
  end
end
