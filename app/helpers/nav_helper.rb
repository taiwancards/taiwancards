# frozen_string_literal: true

module NavHelper
  def language_nav
    taiwan_nav
  end

  GROUPS = [
    {id: "learn", key: :study, tour: "nav-learn", items: :learn_items, chapters: %w[cards], signed_in: true},
    {id: "dictionary", key: :characters, tour: "nav-dictionary", items: :dictionary_items, chapters: %w[dictionary]},
    {id: "language", key: :book, tour: "nav-language", items: :language_items, chapters: %w[phonetics]},
    {id: "practice", key: :pencil, tour: "nav-practice", items: :practice_items, chapters: %w[trainers]},
    {id: "taiwan", key: :desk, tour: "nav-taiwan", items: :taiwan_items, chapters: %w[taiwan]},
    {
      id: "settings",
      key: :settings,
      tour: "nav-settings",
      items: :settings_items,
      chapters: %w[profile display],
      signed_in: true
    }
  ].freeze

  def taiwan_nav
    GROUPS.filter_map do |group|
      next if group[:signed_in] && current_user.nil?

      {
        type: :menu,
        id: group[:id],
        key: group[:key],
        label: t("nav.group_#{group[:id]}"),
        items: send(group[:items]),
        chapters: group[:chapters],
        tour: group[:tour]
      }
    end
  end

  def learn_items
    items = [
      [:study, t("nav.roadmap"), roadmap_path],
      [:desk, t("nav.today"), desk_path],
      [:decks, t("nav.my_desks"), desks_path],
      [:book, t("nav.reader"), reader_path],
      [:stats, t("nav.placement"), placement_path],
      [:stats, t("nav.plan"), study_plan_path],
      [:study, t("nav.triage"), triage_path]
    ]
    if current_user&.restricted_access?
      items << [:book, t("nav.textbook"), textbook_path]
      items << [:sentences, t("nav.phrase_drills"), textbook_phrases_path]
    end

    items
  end

  def dictionary_items
    [
      [:pencil, t("nav.radicals"), radicals_path],
      [:characters, t("nav.characters"), characters_path],
      [:words, t("nav.dict"), dict_path],
      [:sentences, t("nav.sentences"), sentences_path],
      [:book, t("nav.chengyu"), chengyu_path],
      [:words, t("nav.liangci"), liangci_path],
      [:stats, t("nav.tbcl"), tbcl_levels_path],
      [:stats, t("nav.tocfl"), tocfl_levels_path]
    ]
  end

  def language_items
    [
      [:book, t("nav.phonetics"), practice_zhuyin_path],
      [:study, t("nav.tones"), tones_path],
      [:characters, t("nav.hanzi"), hanzi_path],
      [:stats, t("nav.numbers"), practice_numbers_path],
      [:book, t("nav.grammar"), grammar_path],
      [:characters, t("nav.variants"), variants_path]
    ]
  end

  def practice_items
    [
      [:speaker, t("nav.zhuyin_trainer"), zhuyin_training_path],
      [:characters, t("nav.sounds_drill"), practice_drill_path],
      [:speaker, t("nav.tones_drill"), tones_drill_path],
      [:stats, t("nav.pronunciation"), pronunciation_path],
      [:pencil, t("nav.writing"), writing_path],
      [:keyboard, t("nav.typing"), practice_typing_path],
      [:keyboard, t("nav.cangjie"), cangjie_path],
      [:stats, t("nav.mock"), mock_exams_path]
    ]
  end

  def taiwan_items
    [
      [:sentences, t("nav.everyday"), everyday_path],
      [:book, t("nav.phrases"), phrases_path],
      [:desk, t("nav.metro"), metro_path],
      [:book, t("nav.calendar"), calendar_path]
    ]
  end

  def settings_items
    [
      [:user, t("nav.profile"), profile_path],
      [:stats, t("nav.progress"), progress_path],
      [:settings, t("nav.settings"), edit_settings_path],
      [:help, t("nav.guide"), guide_path]
    ]
  end

  MOBILE_TAB_SLOTS = 4

  def mobile_tab_groups
    language_nav.map do |entry|
      [entry[:label], entry[:items].map { |icon_key, label, path| [path, icon_key, label] }]
    end
  end

  def mobile_tab_catalog
    language_nav.flat_map { |entry| entry[:items] }.to_h { |icon_key, label, path| [path, [icon_key, label]] }
  end

  def default_mobile_tabs
    return [characters_path, dict_path, sentences_path, everyday_path] if current_user.nil?

    [desk_path, desks_path, reader_path, pronunciation_path]
  end

  def mobile_tabs
    catalog = mobile_tab_catalog
    chosen = current_user&.mobile_tabs.to_a.select { |path| catalog.key?(path) }
    chosen = default_mobile_tabs.select { |path| catalog.key?(path) } if chosen.empty?

    chosen.first(MOBILE_TAB_SLOTS).map { |path| [*catalog.fetch(path), path] }
  end

  def nav_item_tour(path)
    slug = Locales.strip(path.to_s).split("?").first.to_s.gsub(%r{\A/+|/+\z}, "").tr("/", "-")
    "nav-item-#{slug.presence || "home"}"
  end

  def nav_entry_active?(entry)
    if entry[:type] == :menu
      entry[:items].any? { |_key, _label, path| current_page?(path) }
    else
      current_page?(entry[:path])
    end
  end

  def nav_top_classes(active)
    class_names(
      "flex items-center gap-1.5 whitespace-nowrap border-b-2 px-3 py-2.5 text-sm font-medium transition-colors",
      active ? "border-primary text-foreground" : "border-transparent text-muted-foreground hover:text-foreground"
    )
  end

  def nav_menu_item_classes(active)
    class_names(
      "flex items-center gap-2 rounded-md px-3 py-2 text-sm font-medium transition-colors",
      active ? "bg-muted text-foreground" : "text-muted-foreground hover:bg-muted hover:text-foreground"
    )
  end
end
