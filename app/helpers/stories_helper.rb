# frozen_string_literal: true

module StoriesHelper
  OPENING = 24

  def story_category_tabs(selected)
    [[t("stories.all"), stories_path, selected.nil?]] +
      Huayu::ReadingStories::CATEGORIES.map do |category|
        [t("stories.categories.#{category}"), stories_path(category:), selected == category]
      end
  end

  def story_opening(text)
    first = text.translations(I18n.locale).first.presence || text.lines.first.to_s
    first.length > OPENING ? "#{first[0, OPENING]}…" : first
  end
end
