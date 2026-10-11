# frozen_string_literal: true

module Admin
  class TrafficController < ApplicationController
    before_action :require_admin

    def index
      @days = params[:days].to_i.presence_in(Admin::Traffic::WINDOWS) || Admin::Traffic::WINDOWS.second
      @traffic = Admin::Traffic.new(days: @days)
    end
  end
end
