# frozen_string_literal: true

class Lexeme < ApplicationRecord
  has_many :memories, class_name: "LexemeMemory", dependent: :destroy
  has_many :parent_links, class_name: "LexemeLink", foreign_key: :child_id, dependent: :destroy, inverse_of: :child
  has_many(
    :child_links,
    -> { order(:position) },
    class_name: "LexemeLink",
    foreign_key: :parent_id,
    dependent: :destroy,
    inverse_of: :parent
  )
  has_many :components, through: :child_links, source: :child
  has_many :containers, through: :parent_links, source: :parent
  has_many :collection_items, dependent: :delete_all
  has_many :collections, through: :collection_items

  has_many :lexeme_content_sources, dependent: :delete_all
  has_many :content_sources, through: :lexeme_content_sources
  has_many :senses, -> { order(:position) }, class_name: "LexemeSense", dependent: :destroy, inverse_of: :lexeme
  has_many :sense_examples, dependent: :nullify
  has_one :sentence_profile, dependent: :destroy

  enum(
    :kind,
    {character: 0, word: 1, phrase: 2, radical: 3, sentence: 4, collocation: 5, measure_word: 6}
  )

  DICTIONARY_KINDS = %i[word collocation].freeze
  PUBLIC_ID_KINDS = %i[sentence].freeze
  PUBLIC_ID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  validates :text, presence: true, uniqueness: {scope: :kind}
  validate :attributed_material_has_a_source

  before_create :assign_public_id

  def to_param
    public_id.presence || id&.to_s
  end

  scope :ordered, -> { order(:kind, :text) }
  scope :with_source, -> (tag) { where("sources @> ?", [tag].to_json) }
  scope :unrestricted, -> { where(restricted: false) }

  VISIBLE_SQL = <<~SQL
    lexemes.kind <> #{kinds[:sentence]}
    OR NOT EXISTS (
      SELECT 1 FROM lexeme_content_sources lcs WHERE lcs.lexeme_id = lexemes.id
    )
    OR EXISTS (
      SELECT 1 FROM lexeme_content_sources lcs
      WHERE lcs.lexeme_id = lexemes.id AND lcs.content_source_id IN (%s)
    )
  SQL
    .squish

  scope(
    :permitted_to,
    -> (user) {
      ids = Current.source_ids_for(user)
      list = ids.presence || [0]
      scope = where(Arel.sql(format(VISIBLE_SQL, list.map(&:to_i).join(","))))
      user&.restricted_access? ? scope : scope.where(restricted: false)
    }
  )
  scope :permitted, -> { permitted_to(Current.user) }

  scope(:visible_to, -> (user) { permitted_to(user).projected_for(user) })
  scope :visible, -> { visible_to(Current.user) }

  def self.visibility_key(user = Current.user)
    scale = user&.visibility_scale || "chars"
    projection = if scale == "chars"
      ["chars", user&.character_tier || Huayu::CharacterTiers::COMMON]
    else
      [scale, user.visibility_level, user.visibility_tolerance]
    end

    [
      *projection,
      user&.restricted_access? ? "all" : "open",
      Current.source_ids_for(user).sort.join("-")
    ].join(":")
  end

  scope(:within_tier, -> (level) { where(tier: ..level.to_i) })

  scope(
    :projected_for,
    -> (user) {
      scale = user&.visibility_scale || "chars"
      next within_tier(user&.character_tier || Huayu::CharacterTiers::COMMON) if scale == "chars"
      next all if user.full_visibility?

      column = Huayu::LevelThresholds::COLUMNS.fetch(scale).fetch(user.visibility_tolerance)
      where(column => ..user.visibility_level)
    }
  )

  def outside_projection?(user)
    return false if user.nil? || user.full_visibility?

    if user.visibility_scale == "chars"
      tier > user.character_tier
    else
      column = Huayu::LevelThresholds::COLUMNS.fetch(user.visibility_scale).fetch(user.visibility_tolerance)
      public_send(column) > user.visibility_level
    end
  end

  ATTRIBUTABLE_KINDS = %w[sentence].freeze

  def attributable?
    ATTRIBUTABLE_KINDS.include?(kind)
  end

  LEVEL_INDEX_SQL = "lexemes.level_index"
  FREQ_RANK_SQL = "lexemes.freq_rank"
  MOE_INDEX_SQL = "lexemes.moe_index"

  CURRICULUM_ORDER = %i[level_index freq_rank moe_index text].freeze
  FREQUENCY_ORDER = %i[freq_rank moe_index text].freeze

  scope(:curriculum_order, -> { order(*CURRICULUM_ORDER) })
  scope(:frequency_order, -> { order(*FREQUENCY_ORDER) })

  scope(:at_level, -> (grade) { where(level_index: grade.to_i) })
  scope(:up_to_level, -> (grade) { where(level_index: ..grade.to_i) })

  before_save(
    :rebuild_search_text,
    if: -> {
      will_save_change_to_text? ||
        will_save_change_to_readings? ||
        will_save_change_to_meanings? ||
        will_save_change_to_data?
    }
  )

  before_save(:assign_tier, if: -> { will_save_change_to_text? || will_save_change_to_kind? })

  UNGATED_KINDS = %w[radical].freeze

  def assign_tier
    return self.tier = Huayu::CharacterTiers::COMMON if UNGATED_KINDS.include?(kind)

    self.tier = Huayu::CharacterTiers.text_tier(text) || Huayu::CharacterTiers::RARE
  end

  def rebuild_search_text
    return self.search_text = nil if sentence?

    self.search_text = Huayu::ReadingForms.search_bag(
      text: text,
      readings: reading_set,
      meanings: meanings.values
    )
  end

  def reading(system = nil)
    return readings if system.nil?

    readings[system.to_s]
  end

  def meaning(locale = I18n.locale)
    value = meanings[locale.to_s].presence || meanings.values.find(&:present?)
    value.is_a?(Array) ? value.join("; ") : value
  end

  def containing_words
    containers.where(kind: :word)
  end

  def reading_set
    data["readings"].presence || [readings.presence].compact
  end

  def words_for_reading(pinyin)
    Lexeme.where(kind: :word).where(id: parent_links.where(reading: pinyin).select(:parent_id))
  end

  def add_source(tag)
    return if sources.include?(tag)

    self.sources = sources + [tag]
  end

  private

  def assign_public_id
    return unless PUBLIC_ID_KINDS.include?(kind&.to_sym)
    return if public_id.present?

    self.public_id = SecureRandom.uuid_v7
  end

  def attributed_material_has_a_source
    return unless attributable?
    return if lexeme_content_sources.any? || content_sources.any?

    errors.add(:content_sources, :blank)
  end
end
