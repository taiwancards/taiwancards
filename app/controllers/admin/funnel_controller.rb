# frozen_string_literal: true

module Admin
  class FunnelController < ApplicationController
    before_action :require_admin

    def index
      funnel = Admin::Funnel.new
      @cohorts = funnel.cohorts
      @sources = funnel.sources
      @doors = funnel.doors
    end
  end
end
