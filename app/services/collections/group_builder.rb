# frozen_string_literal: true

module Collections
  class GroupBuilder
    NAME_RETRIES = 3

    def initialize(user: Current.user)
      @user = user
    end

    def call(name:)
      wanted = name.to_s.strip.first(120).presence || default_name
      attempt = 0
      begin
        CollectionGroup.create!(user: @user, name: suffixed(wanted, attempt), position: next_position)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        attempt += 1
        raise if attempt > NAME_RETRIES

        retry
      end
    end

    private

    def suffixed(wanted, attempt)
      attempt.zero? ? wanted : "#{wanted.first(110)} (#{attempt + 1})"
    end

    def default_name
      I18n.t("groups.default_name", count: CollectionGroup.owned_by(@user).count + 1)
    end

    def next_position
      CollectionGroup.owned_by(@user).maximum(:position).to_i + 1
    end
  end
end
