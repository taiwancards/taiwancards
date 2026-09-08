# frozen_string_literal: true

module Deploy
  class Fillers
    def initialize(io: $stdout)
      @io = io
    end

    def call
      MaintenanceWindow.open!

      SyncSteps::FILLERS.filter_map do |name|
        service = name.safe_constantize
        next @io.puts("#{name}: not in this build") if service.nil?

        run(name, service)
      end
    end

    private

    def run(name, service)
      @io.puts("#{name}: #{service.new.call.inspect}")
      nil
    rescue => e
      warn("#{name} failed: #{e.class}: #{e.message}")
      "#{name} (#{e.class})"
    end
  end
end
