# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :user_resolved
  attribute :visible_source_ids

  def user=(person)
    self.user_resolved = true
    super
  end

  def user_resolved? = user_resolved.present?
end
