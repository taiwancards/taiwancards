# frozen_string_literal: true

module Admin
  class PageLabels
    Label = Data.define(:text, :hidden)
    Resolver = Data.define(:key, :lookup)

    NUMBER = /\A\d+\z/

    REGISTRY = {
      "sentences" => Resolver.new(key: :id, lookup: :sentences),
      "markup" => Resolver.new(key: :id, lookup: :sentences),
      "grammar" => Resolver.new(key: :id, lookup: :grammar_lessons),
      "graded" => Resolver.new(key: %i[tier id], lookup: :graded_texts),
      "reader" => Resolver.new(key: :id, lookup: :reading_texts),
      "stories" => Resolver.new(key: :id, lookup: :reading_texts),
      "course" => Resolver.new(key: %i[slug stage], lookup: :course_pages),
      "starter_lessons" => Resolver.new(key: :slug, lookup: :starter_lessons),
      "exams" => Resolver.new(key: :slug, lookup: :exam_papers),
      "cangjie_lessons" => Resolver.new(key: :id, lookup: :cangjie_lessons),
      "notices" => Resolver.new(key: :situation, lookup: :notice_situations),
      "phrases" => Resolver.new(key: :scene, lookup: :phrase_scenes),
      "word_pairs" => Resolver.new(key: :id, lookup: :word_pairs),
      "tocfl" => Resolver.new(key: :id, lookup: :collections),
      "textbook" => Resolver.new(key: %i[book lesson], lookup: :textbook_lessons),
      "collections" => Resolver.new(key: :id, lookup: :collections),
      "collection_groups" => Resolver.new(key: :id, lookup: :own_groups),
      "deck_shares" => Resolver.new(key: :token, lookup: :deck_shares),
      "doors" => Resolver.new(key: :door, lookup: :doors),
      "admin/users" => Resolver.new(key: :id, lookup: :users),
      "admin/newsletters" => Resolver.new(key: :id, lookup: :newsletters)
    }.freeze

    def initialize(locale: I18n.locale)
      @locale = locale
    end

    def call(routes)
      by_resolver = routes.compact.uniq.group_by { |route| REGISTRY[route[:controller]] }.except(nil)

      by_resolver.each_with_object({}) do |(resolver, group), labels|
        keys = group.to_h { |route| [route, key_of(resolver, route)] }.compact
        found = send(resolver.lookup, keys.values.uniq)
        keys.each do |route, key|
          label = found[key]
          labels[route] = labeled(label) if label.present?
        end
      end
    end

    private

    attr_reader :locale

    def key_of(resolver, route)
      values = Array(resolver.key).map { |name| route[name]&.dup&.force_encoding(Encoding::UTF_8) }
      return nil if values.none?

      resolver.key.is_a?(Array) ? values : values.first
    end

    def labeled(label) = label.is_a?(Label) ? label : Label.new(text: StoredPath.visible(label), hidden: false)

    def hidden(kind) = Label.new(text: I18n.t("admin_pages.#{kind}", locale:), hidden: true)

    def numbers(keys) = keys.grep(NUMBER).map(&:to_i)

    def sentences(keys)
      public_ids = keys.map(&:downcase).grep(Lexeme::PUBLIC_ID_FORMAT)
      ids = numbers(keys)
      return {} if public_ids.empty? && ids.empty?

      scope = Lexeme.where(kind: :sentence)
      scope
        .where(public_id: public_ids)
        .or(scope.where(id: ids))
        .pluck(:id, :public_id, :text)
        .each_with_object({}) do |(id, public_id, text), found|
          found[id.to_s] = text
          keys.each { |key| found[key] = text if key.casecmp?(public_id.to_s) }
        end
    end

    def grammar_lessons(keys) = keys.index_with { |slug| Huayu::GrammarLessons.find(slug)&.pattern }

    def graded_texts(keys)
      keys.index_with do |tier, id|
        next I18n.t("graded.tiers.#{tier}", locale:, default: nil) if id.nil? && Graded::Levels.find(tier)

        text = id && Graded::Library.find(tier, id)
        text && (text.titles["zh"].presence || text.title(locale))
      end
    end

    def reading_texts(keys)
      ReadingText.where(id: numbers(keys)).pluck(:id, :user_id, :title).to_h do |id, user_id, title|
        [id.to_s, user_id ? hidden(:own_text) : title]
      end
    end

    def course_pages(keys)
      keys.index_with do |slug, stage|
        slug ? Huayu::CourseLessons.find(slug)&.title_for(locale) : Huayu::CourseLessons.stage(stage)&.title(locale)
      end
    end

    def starter_lessons(keys) = keys.index_with { |slug| Huayu::StarterTrack.find(slug)&.title_for(locale) }

    def exam_papers(keys)
      keys.index_with do |slug|
        paper = Huayu::TocflPapers.find(slug)
        paper && I18n.with_locale(locale) { "#{paper.label} · #{I18n.t("exams.skills.#{paper.skill}")}" }
      end
    end

    def cangjie_lessons(keys) = keys.index_with { |slug| Huayu::CangjieLessons.find(slug)&.title_for(locale) }

    def notice_situations(keys)
      keys.index_with do |situation|
        I18n.t("notices.situations.#{situation}.name", locale:) if Huayu::TaiwanNotices::SITUATIONS.include?(situation)
      end
    end

    def phrase_scenes(keys) = keys.index_with { |scene| Huayu::TaiwanPhrases.scene(scene)&.zh }

    def word_pairs(keys) = keys.index_with { |slug| Huayu::WordPairs.find(slug)&.title }

    def textbook_lessons(keys)
      pairs = keys.select { |pair| pair.all?(NUMBER) }.map { |pair| pair.map(&:to_i) }
      return {} if pairs.empty?

      TextbookLesson
        .where(%i[book lesson] => pairs)
        .pluck(:book, :lesson, :title_zh, :title_en)
        .to_h { |book, lesson, zh, en| [[book.to_s, lesson.to_s], zh.presence || en] }
    end

    def collections(keys)
      Collection.where(id: numbers(keys)).pluck(:id, :user_id, :name).to_h do |id, user_id, name|
        [id.to_s, user_id ? hidden(:own_deck) : name]
      end
    end

    def own_groups(keys) = CollectionGroup.where(id: numbers(keys)).pluck(:id).to_h { |id|
      [id.to_s, hidden(:own_group)]
    }

    def deck_shares(keys) = DeckShare.where(token: keys).pluck(:token, :name).to_h

    def doors(keys)
      keys.index_with { |door| I18n.t("doors.#{door}.door", locale:) if Onboarding::Entry::DOORS.include?(door) }
    end

    def users(keys)
      User.where(id: numbers(keys)).pluck(:id, :name, :email).to_h { |id, name, email|
        [id.to_s, name.presence || email]
      }
    end

    def newsletters(keys)
      Newsletter
        .where(id: numbers(keys))
        .pluck(:id, Newsletter.field("subject", locale), :subject_en)
        .to_h { |id, subject, fallback| [id.to_s, subject.presence || fallback] }
    end
  end
end
