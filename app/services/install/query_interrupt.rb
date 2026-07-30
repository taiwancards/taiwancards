# frozen_string_literal: true

module Install
  module QueryInterrupt
    module_function

    def install!
      return if @installed

      @installed = true
      previous = Signal.trap("INT") do
        cancel_backend
        previous.respond_to?(:call) ? previous.call : exit(130)
      end
    end

    def cancel_backend
      raw = ActiveRecord::Base.connection.raw_connection
      raw.cancel if raw.respond_to?(:cancel)
    rescue StandardError
      nil
    end
  end
end
