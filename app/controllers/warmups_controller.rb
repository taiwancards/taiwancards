# frozen_string_literal: true

class WarmupsController < ApplicationController
  def show
    @prompts = prompts_with_audio
    @profile = profile
  end

  def create
    return head(:unprocessable_entity) if params[:audio].blank?

    analysis = Pronunciation::WarmupAnalysis.new.call(params[:audio])
    return render(json: {ok: false, error: "too_short"}) if analysis.nil?

    result = Pronunciation::Calibration.ingest(
      profile,
      analysis,
      kind: params[:kind],
      tone: params[:tone],
      locale: I18n.locale.to_s
    )
    render(json: result)
  end

  def destroy
    profile.destroy
    redirect_to(pronunciation_warmup_path, notice: t("pron.ui.warmup_redo"))
  end

  private

  def prompts_with_audio
    steps = Pronunciation::Calibration::TONE_STEPS.index_by { |step| step[:id] }
    lexemes = Lexeme.where(kind: %i[word character], text: steps.values.pluck(:char)).index_by(&:text)

    Pronunciation::Calibration.prompts_for(I18n.locale).map do |prompt|
      step = steps[prompt[:id]]
      next prompt if step.nil?

      lexeme = lexemes[step[:char]]
      prompt.merge(
        zhuyin: step[:zhuyin],
        pinyin: step[:pinyin],
        audio: lexeme && helpers.audio_for(lexeme)&.fetch(:url, nil)
      )
    end
  end

  def profile
    @profile ||= VoiceProfile.find_or_create_by!(user: Current.user)
  end
end
