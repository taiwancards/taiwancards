# frozen_string_literal: true

class PronunciationJudgementsController < ApplicationController
  before_action :require_restricted_access

  PAGE = 12

  def index
    @pending = PronunciationRecording.unrated.oldest_first.limit(PAGE).to_a
    @tally = PronunciationRecording.group(:verdict).count
    @coverage = coverage
  end

  def audio
    recording = PronunciationRecording.find(params[:id])

    send_data(
      recording.audio,
      type: recording.content_type.presence || "audio/webm",
      disposition: "inline"
    )
  end

  def update
    recording = PronunciationRecording.find(params[:id])
    recording.rate!(verdict, rejected: Array(params[:rejected]), note: params[:note])

    redirect_to(pronunciation_judgements_path, notice: t("pron.judge.saved"))
  end

  def destroy
    PronunciationRecording.find(params[:id]).destroy!

    redirect_to(pronunciation_judgements_path, notice: t("pron.judge.dropped"))
  end

  private

  def verdict
    params[:verdict].to_s.presence_in(PronunciationRecording::VERDICTS.keys.map(&:to_s)) || "unsure"
  end

  def coverage
    keys = PronunciationRecording.rated.pluck(:syllable_keys).flatten
    {"rated" => keys.length, "distinct" => keys.uniq.length}
  end
end
