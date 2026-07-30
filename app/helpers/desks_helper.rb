# frozen_string_literal: true

module DesksHelper
  def recent_desks(limit: 10)
    return [] unless current_user

    @recent_desks ||= Collection
      .desks_for(current_user)
      .recent
      .limit(limit)
      .to_a
  end
end
