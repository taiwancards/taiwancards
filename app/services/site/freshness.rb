# frozen_string_literal: true

require "tmpdir"

module Site
  class Freshness
    def initialize(root: Rails.root.join("site"))
      @root = Pathname(root)
    end

    def missing_env = Exporter::REQUIRED.reject { |name| ENV[name].present? }

    def drift
      Dir.mktmpdir("taiwancards-site") do |dir|
        fresh = Pathname(dir)
        Exporter.new(root: fresh, io: StringIO.new).call
        differences(fresh)
      end
    end

    private

    attr_reader :root

    def differences(fresh)
      (files(root) | files(fresh)).sort.reject { |path| identical?(root.join(path), fresh.join(path)) }
    end

    def files(base)
      base.glob("**/*").select(&:file?).map { |path| path.relative_path_from(base).to_s }.to_set
    end

    def identical?(left, right)
      left.file? && right.file? && left.binread == right.binread
    end
  end
end
