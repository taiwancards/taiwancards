# frozen_string_literal: true

class HanziController < ApplicationController
  allow_unauthenticated_access
  def show
    @structure = Huayu::HanziStructure
  end
end
