# frozen_string_literal: true

module OfflineFakeWorker
  SCRIPT = <<~'RUBY'
    input = IO.for_fd(3, "rb")
    output = IO.for_fd(4, "wb")
    while (job = Offline::Frames.read(input))
      exit!(1) if job["paths"].include?("/die")
      fragments = job["paths"].grep_v(/refuse/).to_h do |path|
        [path, {"t" => path, "w" => "narrow", "m" => "#{job["locale"]}:#{path}:#{Process.pid}"}]
      end
      refused = job["paths"].grep(/refuse/).map { |path| "/#{job["locale"]}#{path} answered 302" }
      Offline::Frames.write(output, {"fragments" => fragments, "refused" => refused})
    end
  RUBY

  COMMAND = [RbConfig.ruby, "-r", Rails.root.join("app/services/offline/frames.rb").to_s, "-e", SCRIPT].freeze
end
