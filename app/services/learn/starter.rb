# frozen_string_literal: true

module Learn
  class Starter
    PREFIX = "starter:"
    TRACK_STEPS = %w[zhuyin_theory zhuyin drill].freeze
    FRESH_CARDS = 30

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def eligible?
      return @eligible if defined?(@eligible)

      @eligible = user.beginner? && Huayu::StarterTrack.available? && (completed.any? || fresh?)
    end

    def active? = eligible? && next_lesson.present?

    def done?(lesson) = completed.include?(lesson.slug)

    def done_count = completed.size

    def next_lesson = Huayu::StarterTrack.lessons.find { |lesson| !done?(lesson) }

    def complete!(lesson, symbols:, words:)
      lexemes = Lexeme.where(id: words.keys).to_a

      ActiveRecord::Base.transaction do
        record_symbols(symbols)
        grade(lexemes, words)
        deck.add_lexemes(lexemes.map(&:id))
        CourseCompletion.record(
          user:,
          slug: "#{PREFIX}#{lesson.slug}",
          score: words.count { |_id, correct| correct },
          total: words.size
        )
        @completed = nil
        finish_track if next_lesson.nil?
      end

      lexemes
    end

    def deck
      names = I18n.available_locales.map { |locale| I18n.t("starter.deck", locale:) }
      Collection.desks_for(user).find_by(name: names) ||
        Collection.create!(user:, kind: :manual, name: I18n.t("starter.deck", locale: user.locale))
    end

    private

    def fresh? = LexemeMemory.active.owned_by(user).where.not(state: :unseen).distinct.count(:lexeme_id) < FRESH_CARDS

    def scope = CourseCompletion.owned_by(user).where("slug LIKE ?", "#{PREFIX}%")

    def completed
      @completed ||= scope.pluck(:slug).to_set { |slug| slug.delete_prefix(PREFIX) }
    end

    def record_symbols(results)
      return if results.empty?

      trainer = Huayu::ZhuyinTrainer.new(user.zhuyin_mastery)
      results.each { |symbol, correct| trainer.record(symbol, correct:) if Huayu::ZhuyinTrainer::ALL.include?(symbol) }
      user.update_zhuyin_mastery!(trainer.mastery)
      user.record_practice_run!(:zhuyin_trainer)
    end

    def grade(lexemes, results)
      activator = Lexemes::Activator.new(user:)
      processor = Lexemes::ReviewProcessor.new

      lexemes.each do |lexeme|
        memory = activator.activate(lexeme, :recognition)
        next unless memory.state_unseen?

        processor.call(memory, rating: results[lexeme.id] ? "good" : "again")
      end
    end

    def finish_track
      user.update!(prefs: user.prefs.merge("path_steps" => user.path_steps_done | TRACK_STEPS))
    end
  end
end
