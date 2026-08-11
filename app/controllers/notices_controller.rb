# frozen_string_literal: true

class NoticesController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable

  def index
    @categories = Huayu::TaiwanNotices.categories
    @category = params[:category].presence_in(@categories)
    @notices = @category ? Huayu::TaiwanNotices.in_category(@category) : Huayu::TaiwanNotices.all
    @tokens = tokens_for(@notices)
  end

  private

  def tokens_for(notices)
    lines = notices.flat_map { |notice| [notice.zh, *notice.items.map(&:zh)] }.compact
    Huayu::TextAnalyzer.new(locale: I18n.locale).analyze_map(lines)
  end
end
