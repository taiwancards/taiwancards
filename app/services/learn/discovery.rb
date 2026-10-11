# frozen_string_literal: true

module Learn
  class Discovery
    KINDS = %w[grammar graded phrases pronunciation].freeze
    KNOWN_SHARE = 80
    READER_WORDS = 100
    FRESH_DAYS = 7
    MEMORY_DAYS = 30

    Suggestion = Data.define(:kind, :subject, :level)

    def initialize(user, now: Time.current)
      @user = user
      @now = now
    end

    def call(except: nil)
      options = options(except:)
      return nil if options.empty?

      stale = options.reject { |option| fresh_controllers.include?(option.kind) }
      pool = stale.presence || options
      pool[@now.to_date.yday % pool.size]
    end

    def options(except: nil) = KINDS.excluding(except.to_s).filter_map { |kind| send(:"#{kind}_suggestion") }

    def grade = @grade ||= [@user.level_grade, card_grade].max

    def working_grade = (grade + 1).clamp(1, Huayu::GrammarLessons.levels.keys.max || 1)

    private

    def grammar_suggestion
      return nil if beginner?

      levels = Huayu::GrammarLessons.levels
      lesson = levels
        .keys
        .sort
        .select { |level| level >= working_grade }
        .lazy
        .filter_map { |level|
          levels[level].find { |entry| seen_paths.exclude?("/grammar/#{entry.to_param}") }
        }
        .first
      lesson && Suggestion.new(kind: "grammar", subject: lesson, level: lesson.level)
    end

    def graded_suggestion
      return nil if known_words < READER_WORDS

      tier = Graded::Levels
        .all
        .select { |entry| entry.size <= known_words && Graded::Library.texts(entry.id).any? }
        .last
      return nil if tier.nil?

      text = Graded::Library.texts(tier.id).find { |entry| seen_paths.exclude?("/graded/#{tier.id}/#{entry.id}") }
      text && Suggestion.new(kind: "graded", subject: text, level: tier.size)
    end

    def phrases_suggestion
      scenes = Huayu::TaiwanPhrases.scenes
      return nil if scenes.empty?

      Suggestion.new(kind: "phrases", subject: scenes[(@now.to_date.cweek + @user.id) % scenes.size], level: nil)
    end

    def pronunciation_suggestion
      practiced = PronunciationAttempt.owned_by(@user).where(created_at: (@now - FRESH_DAYS.days)..).exists?
      practiced ? nil : Suggestion.new(kind: "pronunciation", subject: nil, level: nil)
    end

    def beginner? = Learn::Starter.new(@user).active?

    def card_grade
      Huayu::TocflReadiness.new(user: @user).levels.take_while { |stat| stat.readiness >= KNOWN_SHARE }.size
    end

    def known_words
      @known_words ||= LexemeMemory
        .owned_by(@user)
        .state_review
        .where(facet: LexemeMemory.facets[:recognition])
        .joins(:lexeme)
        .where(lexemes: {kind: %i[word character]})
        .count
    end

    def events
      @events ||= ActivityEvent
        .where(user: @user, created_at: (@now - MEMORY_DAYS.days)..)
        .pluck(:controller, :path, :created_at)
    end

    def seen_paths = @seen_paths ||= events.to_set { |_controller, path, _at| path }

    def fresh_controllers
      @fresh_controllers ||= events
        .filter_map { |controller, _path, at| controller if at > @now - FRESH_DAYS.days }
        .to_set
    end
  end
end
