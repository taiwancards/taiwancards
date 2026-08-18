# frozen_string_literal: true

class SyllablesController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable

  def show
    @groups = Huayu::SyllableChart.groups
    @clips = Huayu::SyllableChart.size
    @bases = Huayu::SyllableChart.bases
    @voices = Huayu::SyllableChart.voices
    @templates = Huayu::SyllableChart.templates
  end
end
