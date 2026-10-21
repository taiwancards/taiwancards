# frozen_string_literal: true

class DictationsController < ApplicationController
  allow_unauthenticated_access

  def show
    @level = Dictation::Round.level(params[:level], current_user)
    @items = Dictation::Round.new(level: @level, locale: I18n.locale).items
    @layout = Huayu::ZhuyinKeyboard.layout
  end

  def create
    @row = Huayu::ListeningClips.by_clip(params[:clip].to_s)
    return head(:unprocessable_content) if @row.nil?

    grader = Dictation::Grader.new(@row.text)
    @result = grader.call(params[:answer])
    @sentence = grader.sentence
    current_user&.record_practice_run!(:dictation) if params[:last].present?
  end
end
