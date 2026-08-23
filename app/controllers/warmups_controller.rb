# frozen_string_literal: true

class WarmupsController < ApplicationController
  def show
    @prompts = prompts_with_audio
    @profile = profile
    @done_url = take_return_path || pronunciation_path
  end

  def create
    return head(:unprocessable_entity) if params[:audio].blank?

    heard = profile.f0_low
    analysis = Pronunciation::Admission.take { Pronunciation::WarmupAnalysis.new.call(params[:audio], f0_low: heard) }
    return render(json: {ok: false, error: "busy"}, status: :too_many_requests) if analysis == :busy
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

      clip = lexemes[step[:char]].then { |lexeme| lexeme && helpers.audio_for(lexeme) }
      prompt.merge(
        zhuyin: step[:zhuyin],
        pinyin: step[:pinyin],
        audio: clip&.fetch(:url, nil),
        audio_stop: clip&.fetch(:stop_ms, nil)
      )
    end
  end

  def profile
    @profile ||= VoiceProfile.find_or_create_by!(user: Current.user)
  end
end
