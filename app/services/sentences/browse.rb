# frozen_string_literal: true

module Sentences
  class Browse
    PER_PAGE = 10

    Result = Data.define(:rows, :total, :page, :pages, :per_page)

    def initialize(user:, params: {})
      @user = user
      @params = params
    end

    def call
      total = cached_total
      pages = [(total / PER_PAGE.to_f).ceil, 1].max
      profiles = scope.ordered.offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a

      Result.new(rows: rows_for(profiles), total:, page:, pages:, per_page: PER_PAGE)
    end

    def level_for(scheme)
      value = @params.dig(:levels, scheme).presence
      value if SentenceProfile::SCHEMES.fetch(scheme.to_s)[:levels].include?(value)
    end

    def registers
      @registers ||= Array(@params[:registers]).map(&:to_s) & ContentSource.registers.keys
    end

    def guaranteed_only?
      ActiveModel::Type::Boolean.new.cast(@params[:guaranteed]).present?
    end

    def page
      @page ||= [@params[:page].to_i, 1].max
    end

    def any_filter?
      word.present? || registers.any? || SentenceProfile::SCHEMES.keys.any? { |scheme| level_for(scheme) }
    end

    def word
      @word ||= @params[:word].to_s.strip.presence
    end

    def word_lexeme
      return nil if word.nil?

      @word_lexeme ||= Lexeme.find_by(kind: %i[word character collocation], text: word)
    end

    def available_registers
      @available_registers ||= ContentSource.registers.keys &
        ContentSource.visible_to(@user).where.not(register: nil).distinct.pluck(:register)
    end

    private

    def cached_total
      ContentCache.fetch("sentences/total", Lexeme.visibility_key(@user), filter_key) { scope.count }
    end

    def filter_key
      levels = SentenceProfile::SCHEMES.keys.map { |scheme| "#{scheme}=#{level_for(scheme)}" }
      [*levels, "registers=#{registers.sort.join(",")}", "word=#{word_lexeme&.id}", "exact=#{guaranteed_only?}"].join(
        "&"
      )
    end

    def scope
      @scope ||= begin
        relation = SentenceProfile
          .visible_to(@user)
          .joins(:lexeme)
          .where(lexemes: {kind: Lexeme.kinds[:sentence]})

        SentenceProfile::SCHEMES.each_key do |scheme|
          level = level_for(scheme)
          next if level.nil?

          relation = relation.at_most(scheme, level)
          relation = relation.guaranteed(scheme) if guaranteed_only?
        end

        relation = relation.in_registers(register_values) if registers.any?

        if word_lexeme
          relation = relation.where(lexeme_id: SentenceWord.where(lexeme_id: word_lexeme.id).select(:sentence_id))
        end

        relation
      end
    end

    def register_values
      registers.map { |name| ContentSource.registers[name] }
    end

    def rows_for(profiles)
      lexemes = Lexeme
        .where(id: profiles.map(&:lexeme_id))
        .includes(:content_sources)
        .index_by(&:id)

      profiles.filter_map do |profile|
        lexeme = lexemes[profile.lexeme_id]
        next if lexeme.nil?

        [lexeme, profile]
      end
    end
  end
end
