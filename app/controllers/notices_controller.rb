# frozen_string_literal: true

class NoticesController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable

  def index
    legacy = legacy_situation
    return redirect_to(notices_situation_path(situation: legacy), status: :moved_permanently) if legacy

    @groups = Huayu::TaiwanNotices.by_situation
  end

  def show
    @situations = Huayu::TaiwanNotices.situations
    @situation = params[:situation].presence_in(@situations)
    raise ActiveRecord::RecordNotFound if @situation.nil?

    @notices = Huayu::TaiwanNotices.in_situation(@situation)
    @tokens = Huayu::TextAnalyzer.new(locale: I18n.locale).analyze_map(@notices.flat_map(&:texts))
  end

  private

  def legacy_situation
    category = params[:category].presence_in(Huayu::TaiwanNotices.categories)
    category && Huayu::TaiwanNotices.in_category(category).first.situation
  end
end
