# frozen_string_literal: true

class VariantsController < ApplicationController
  allow_unauthenticated_access
  def show
    @sections = VariantsHelper::SECTIONS
    @section = params[:section].presence_in(@sections) || @sections.first
  end
end
