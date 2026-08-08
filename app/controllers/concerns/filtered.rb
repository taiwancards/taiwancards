# frozen_string_literal: true

module Filtered
  extend ActiveSupport::Concern

  included do
    class_attribute(:filter_keys, default: [])

    before_action :leave_filtering_to_accounts
  end

  class_methods do
    def filtered_by(*names)
      self.filter_keys = names.map(&:to_s).freeze
    end
  end

  private

  def filtering?
    params[:page].to_i > 1 || filter_keys.any? { |key| params[key].present? }
  end

  def leave_filtering_to_accounts
    require_authentication if filtering?
  end
end
