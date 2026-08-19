# frozen_string_literal: true

module IntroHelper
  def intro_view
    return nil if current_user.nil?

    @intro_view ||= Intro::Runner.new(user: current_user, session: session).call
  end

  def setup_tasks
    progress = current_user&.intro
    return [] if progress.nil? || progress.required?

    tasks = []
    tasks << {label: t("intro.setup.tour"), path: intro_start_path, post: true} if progress.pending?
    tasks << {label: t("intro.setup.level"), path: onboarding_start_path} unless current_user.start_chosen?
    tasks
  end

  def intro_label(view)
    case view.mode
    when :essential
      t("intro.label")
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

  def intro_steps(view)
    return [view.step] unless view.mode == :chapter

    Intro::Map.chapter(view.chapter)&.steps || [view.step]
  end

  def intro_payload(view)
    intro_steps(view)
      .map do |step|
        step.to_payload.merge(
          title: t("#{step.i18n_key}.title", default: step.id.humanize),
          body: t("#{step.i18n_key}.body", default: "")
        )
      end
      .to_json
  end

  def intro_chapter_state(chapter)
    return :done if current_user&.intro&.chapter_done?(chapter.id)

    :new
  end

  def guide_chapters_for(group)
    Array(group[:chapters]).filter_map { |id| Intro::Map.chapter(id) }
  end

  def guide_chapter_label(chapter, done)
    title = t("#{chapter.i18n_key}.title")
    done ? t("intro.guide.again_named", title:) : t("intro.guide.launch_named", title:)
  end
end
