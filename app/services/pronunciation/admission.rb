# frozen_string_literal: true

module Pronunciation
  module Admission
    SEATS = ENV.fetch("PRONUNCIATION_SEATS", 1).to_i
    WAIT = ENV.fetch("PRONUNCIATION_WAIT", 3).to_f

    module_function

    def seats = @seats ||= Concurrent::Semaphore.new([SEATS, 1].max)

    def take
      return :busy unless seats.try_acquire(1, WAIT)

      begin
        yield
      ensure
        seats.release
      end
    end
  end
end
