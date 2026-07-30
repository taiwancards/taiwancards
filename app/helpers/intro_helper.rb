# frozen_string_literal: true

module IntroHelper
  def intro_view
    return nil if current_user.nil?

    @intro_view ||= Intro::Runner.new(user: current_user, session: session).call
  end

  def intro_label(view)
    case view.mode
    when :essential
      t("intro.label")
    when :whats_new
      t("intro.label_whats_new")
    else
      t("intro.chapters.#{view.chapter}.title")
    end
  end

  def intro_title(view)
    t("#{view.step.i18n_key}.title", default: view.step.id.humanize)
  end

  def intro_body(view)
    t("#{view.step.i18n_key}.body", default: "")
  end

  def intro_chapter_state(chapter)
    return :done if current_user&.intro&.chapter_done?(chapter.id)

    :new
  end
end
