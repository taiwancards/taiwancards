# frozen_string_literal: true

module Offline
  MOUNT = SharedAssets::PACKS
  MANIFEST = SharedAssets::MANIFEST

  module_function

  def root = SharedAssets.directory(MOUNT)

  def base
    return "/#{MOUNT}" if Rails.env.development? || SharedAssets.base_url.blank?

    "#{SharedAssets.base_url}/#{MOUNT}"
  end

  def built? = root.join(MANIFEST).exist?

  def rendering? = Thread.current[:offline_rendering].present?

  def while_rendering
    annotated = ActionView::Base.annotate_rendered_view_with_filenames
    reload = Rails.application.reloader.check
    Rails.application.eager_load!
    Rails.application.reloader.check = -> { false }
    ActionView::Base.annotate_rendered_view_with_filenames = false
    ActiveSupport::ExecutionContext.nestable = true
    ActiveSupport::ExecutionContext.push if Rails.application.executor.active?
    Thread.current[:offline_rendering] = true
    yield
  ensure
    Thread.current[:offline_rendering] = nil
    ActionView::Base.annotate_rendered_view_with_filenames = annotated
    Rails.application.reloader.check = reload
  end
end
