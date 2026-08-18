# frozen_string_literal: true

class NamesController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable only: %i[show data]

  def data
    raise ActiveRecord::RecordNotFound unless Huayu::TaiwanNames.available?

    cache_at_the_edge
    render(json: Huayu::TaiwanNames.assistant_payload)
  end

  def show
    raise ActiveRecord::RecordNotFound unless Huayu::TaiwanNames.available?

    @field = params[:field].presence_in(Huayu::TaiwanNames::FIELDS)
    @position = params[:position].presence_in(Huayu::TaiwanNames::POSITIONS)
    @tone = params[:tone].presence_in(%w[1 2 3 4])
    @cohort = params[:cohort].presence_in(Huayu::TaiwanNames::COHORTS)
    @surnames = Huayu::TaiwanNames.surnames
    @characters = Huayu::TaiwanNames.filter(field: @field, position: @position, tone: @tone, cohort: @cohort)
    @cohort_sizes = Huayu::TaiwanNames.cohort_sizes
    @field_counts = Huayu::TaiwanNames.field_counts
    @pairs = Huayu::TaiwanNames.pairs.first(24)
    @meta = Huayu::TaiwanNames.meta
    @source = Huayu::TaiwanNames.source
    @surname_source = Huayu::TaiwanNames.surname_source
    @contours = Huayu::TaiwanNames.contours.first(6)
  end
end
