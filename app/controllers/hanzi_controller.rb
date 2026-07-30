# frozen_string_literal: true

class HanziController < ApplicationController
  def show
    @structure = Huayu::HanziStructure
  end
end
