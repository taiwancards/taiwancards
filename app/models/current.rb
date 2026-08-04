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

  def source_ids_for(scoped_user)
    self.visible_source_ids ||= {}
    key = scoped_user&.id
    return visible_source_ids[key] if visible_source_ids.key?(key)

    visible_source_ids[key] = ContentSource.visible_to(scoped_user).pluck(:id)
  end
end
