# frozen_string_literal: true

class HanziController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  def show
    @structure = Huayu::HanziStructure
  end
end
