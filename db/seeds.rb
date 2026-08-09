# frozen_string_literal: true

Setting.instance

result = Accounts::Owner.new.call
puts("Seeds: #{result}") unless Rails.env.test?
