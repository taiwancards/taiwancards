# frozen_string_literal: true

module Offline
  class Worker
    def self.serve(input_fd, output_fd)
      input = IO.for_fd(Integer(input_fd), "rb")
      output = IO.for_fd(Integer(output_fd), "wb")
      Offline.while_rendering { new.call(input, output) }
    end

    def initialize(renderer: Renderer.new)
      @renderer = renderer
    end

    def call(input, output)
      while (job = Frames.read(input))
        Frames.write(output, perform(job.fetch("locale"), job.fetch("paths")))
      end
    end

    def perform(locale, paths)
      refused = []
      fragments = paths.each_with_object({}) do |path, acc|
        fragment = render(path, locale, refused)
        acc[path] = fragment if fragment
      end

      {"fragments" => fragments, "refused" => refused}
    end

    private

    attr_reader :renderer

    def render(path, locale, refused)
      Fragment.new(renderer.call(path, locale)).call
    rescue Renderer::Refused => e
      refused << e.message
      nil
    end
  end
end
