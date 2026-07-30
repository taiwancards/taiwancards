# frozen_string_literal: true

class StudyDisplay
  attr_reader :front, :reading, :examples

  def self.resolve(params, settings: Setting.instance)
    defaults = settings.study_display
    new(
      front: params[:front].presence_in(Setting::FRONT_MODES) || defaults["front"],
      reading: params[:reading].presence_in(Setting::READING_MODES) || defaults["reading"],
      examples: params.key?(:examples) ? params[:examples] == "1" : defaults["examples"]
    )
  end

  def initialize(front: "target", reading: "zhuyin", examples: true)
    @front = front
    @reading = reading
    @examples = examples
  end

  def reading_front?
    front == "reading"
  end

  def examples?
    examples
  end

  def to_params
    {front:, reading:, examples: examples ? "1" : "0"}
  end
end
