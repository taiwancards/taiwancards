# frozen_string_literal: true

module Site
  class Sitemap
    CHUNK = 5_000

    SECTIONS = %w[pages characters dict grammar lists].freeze

    HUBS = %w[
      /dict
      /characters
      /sentences
      /chengyu
      /liangci
      /liangci/game
      /radicals
      /tocfl
      /tbcl
      /grammar
      /hanzi
      /cangjie
      /tones
      /syllables
      /practice/zhuyin
      /practice/numbers
      /handwriting
      /everyday
      /phrases
      /notices
      /medicine
      /calendar
      /metro
      /variants
      /mock
      /graded
      /menu
    ]
      .freeze

    def initialize(origin:)
      @origin = origin.to_s.chomp("/")
    end

    def index
      names.map { |name| {loc: "#{@origin}/sitemaps/#{name}.xml"} }
    end

    def names
      @names ||= SECTIONS.flat_map do |section|
        pages = [(count_for(section).to_f / CHUNK).ceil, 1].max
        pages == 1 ? [section] : (1..pages).map { |page| "#{section}-#{page}" }
      end
    end

    def index_xml
      body = index.map { |row| "  <sitemap><loc>#{CGI.escapeHTML(row[:loc])}</loc></sitemap>" }
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        #{body.join("\n")}
        </sitemapindex>
      XML
    end

    def urlset_xml(name)
      rows = entries(name)
      return nil if rows.empty?

      body = rows.map do |row|
        links = row[:alternates].map do |code, href|
          "    <xhtml:link rel=\"alternate\" hreflang=\"#{code}\" href=\"#{CGI.escapeHTML(href)}\"/>"
        end

        links << "    <xhtml:link rel=\"alternate\" hreflang=\"x-default\" href=\"#{CGI.escapeHTML(row[:default])}\"/>"
        "  <url>\n    <loc>#{CGI.escapeHTML(row[:loc])}</loc>\n#{links.join("\n")}\n  </url>"
      end

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
        #{body.join("\n")}
        </urlset>
      XML
    end

    def entries(name)
      section, page = split(name)
      return [] unless SECTIONS.include?(section)

      slice = paths_for(section)
      slice = slice[((page - 1) * CHUNK), CHUNK].to_a if page
      slice.map { |path| localised(path) }
    end

    def paths_for(section) = build(section)

    def count_for(section)
      case section
      when "pages"
        HUBS.length + optional_pages.length
      when "characters"
        character_scope.count
      when "dict"
        dict_scope.count
      when "grammar"
        Huayu::GrammarLessons.taught.length
      when "lists"
        list_paths.length
      else
        0
      end
    end

    private

    def split(name)
      match = name.to_s.match(/\A(.+?)(?:-(\d+))?\z/)
      [match[1], match[2]&.to_i]
    end

    def localised(path)
      {
        loc: url(path, Locales::DEFAULT),
        alternates: Locales::ALL.map { |code| [code, url(path, code)] },
        default: url(path, Locales::DEFAULT)
      }
    end

    def url(path, code) = "#{@origin}/#{code}#{path == "/" ? "" : path}"

    def build(section)
      case section
      when "pages"
        HUBS + optional_pages
      when "characters"
        character_paths
      when "dict"
        dict_paths
      when "grammar"
        grammar_paths
      when "lists"
        list_paths
      else
        []
      end
    end

    def optional_pages = Huayu::TaiwanNames.available? ? ["/names"] : []

    WORTH_INDEXING = "lexemes.readings ->> 'zhuyin' IS NOT NULL OR " \
      "EXISTS (SELECT 1 FROM lexeme_senses s WHERE s.lexeme_id = lexemes.id)"

    def character_scope = Lexeme.where(kind: :character).where(WORTH_INDEXING)

    def dict_scope = Lexeme.where(kind: %i[word collocation]).where(WORTH_INDEXING)

    def character_paths
      character_scope.order(:text).pluck(:text).map { |text| "/characters/#{ERB::Util.url_encode(text)}" }
    end

    def dict_paths
      dict_scope.order(:text).pluck(:text).map { |text| "/dict/#{ERB::Util.url_encode(text)}" }
    end

    def grammar_paths
      Huayu::GrammarLessons.taught.map { |lesson| "/grammar/#{lesson.id}" }
    end

    def list_paths
      radicals = Lexeme
        .where(kind: :radical)
        .order(:text)
        .pluck(:text)
        .map { |text| "/radicals/#{ERB::Util.url_encode(text)}" }
      measures = Lexeme
        .where(kind: :measure_word)
        .order(:text)
        .pluck(:text)
        .map { |text| "/liangci/#{ERB::Util.url_encode(text)}" }
      tocfl = Collection.tocfl.order(:id).pluck(:id).map { |id| "/tocfl/#{id}" }
      tbcl = Huayu::TbclReadiness::GRADES.map { |grade| "/tbcl/#{grade}" }

      radicals + measures + tocfl + tbcl
    end
  end
end
