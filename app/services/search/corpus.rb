# frozen_string_literal: true

module Search
  class Corpus
    PER_PAGE = 20
    DEPTH = 300
    READING_UNITS = 30
    KINDS = %w[character word collocation radical measure_word].freeze
    ORDERS = %w[easy corpus].freeze

    Result = Data.define(:results, :total, :page, :pages, :per_page) do
      def any? = results.any?

      def empty? = results.empty?
    end

    EMPTY = Result.new(results: [], total: 0, page: 1, pages: 1, per_page: PER_PAGE)

    def initialize(user:, params: {})
      @user = user
      @params = params
    end

    def text = @params[:q].to_s.strip

    def pinyin = @params[:pinyin].to_s.strip

    def zhuyin = @params[:zhuyin].to_s.strip

    def fields = [text, pinyin, zhuyin].select(&:present?)

    def any_query? = fields.any?

    def sentences? = ActiveModel::Type::Boolean.new.cast(@params[:sentences]).present?

    def guaranteed? = ActiveModel::Type::Boolean.new.cast(@params[:guaranteed]).present?

    def kinds
      @kinds ||= (Array(@params[:kinds]).map(&:to_s) & KINDS).presence || KINDS
    end

    def kind?(name) = kinds.include?(name.to_s)

    def registers
      @registers ||= Array(@params[:registers]).map(&:to_s) & ContentSource.registers.keys
    end

    def levels
      @levels ||= SentenceProfile::SCHEMES.to_h do |scheme, config|
        value = @params.dig(:levels, scheme).presence
        [scheme, config[:levels].include?(value.to_s) ? value : nil]
      end
    end

    def order
      @order ||= @params[:order].to_s.presence_in(ORDERS) || ORDERS.first
    end

    def page = [@params[:page].to_i, 1].max

    def available_registers
      @available_registers ||= ContentSource.registers.keys &
        ContentSource.visible_to(@user).where.not(register: nil).distinct.pluck(:register)
    end

    def call
      return EMPTY unless any_query?

      rows = intersected
      rows = filter_by_register(rows) if registers.any?
      return EMPTY if rows.empty?

      pages = [(rows.length / PER_PAGE.to_f).ceil, 1].max
      current = [page, pages].min
      Result.new(
        results: rows[(current - 1) * PER_PAGE, PER_PAGE] || [],
        total: rows.length,
        page: current,
        pages: pages,
        per_page: PER_PAGE
      )
    end

    def concordance
      return Concordance::EMPTY unless any_query?

      groups = sentence_groups
      return Concordance::EMPTY if groups.empty?

      concordance_service.call(
        groups: groups,
        registers: registers,
        levels: levels,
        guaranteed: guaranteed?,
        order: order.to_sym,
        page: page
      )
    end

    def compatibility
      return nil if text.blank?

      units = Huayu::TextAnalyzer.new.segment(text)
      return nil if units.length < 2

      ::Lexemes::Compatibility.new(user: @user).call(units.first(3))
    end

    def sentence_groups
      groups = []
      groups.concat(text_groups) if text.present?
      [pinyin, zhuyin].each do |field|
        next if field.blank?

        unit = reading_units(field)
        groups << unit if unit.any?
      end

      groups
    end

    private

    def concordance_service
      @concordance_service ||= Concordance.new(user: @user)
    end

    def text_groups
      units = Huayu::TextAnalyzer.new.segment(text).presence || [text]
      return [concordance_service.expand(text)] if units.length == 1 && text.length == 1

      units.map { |unit| [unit] }
    end

    def reading_units(field)
      searcher
        .call(field, limit: READING_UNITS, kinds: %w[character word collocation])
        .results
        .map { |result| result.lexeme.text }
        .uniq
    end

    def searcher
      @searcher ||= Lexemes::Search.new
    end

    def intersected
      pages = fields.map { |field| searcher.call(field, limit: DEPTH, kinds: kinds).results }
      return [] if pages.any?(&:empty?)

      shared = pages.map { |results| results.map { |result| result.lexeme.id }.to_set }.reduce(:&)
      pages.first.select { |result| shared.include?(result.lexeme.id) }
    end

    def filter_by_register(rows)
      wanted = registers.map { |name| ContentSource.registers[name] }.compact.to_set
      rows.select do |result|
        mix = result.lexeme.data["register_mix"]
        next false if mix.blank?

        peak = mix.each_with_index.max_by { |share, _| share.to_f }&.last
        wanted.include?(peak)
      end
    end
  end
end
