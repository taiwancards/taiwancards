# frozen_string_literal: true

class HanziController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  def show
    current_user&.record_practice_run!(:hanzi_theory)
    @structure = Huayu::HanziStructure
  end
end
