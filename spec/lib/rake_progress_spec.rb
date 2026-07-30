# frozen_string_literal: true

require "rails_helper"
require "rake_progress"

RSpec.describe RakeProgress do
  def silently
    original = $stdout
    buffer = StringIO.new
    $stdout = buffer
    [yield, buffer.string]
  ensure
    $stdout = original
  end

  def output_of
    original = $stdout
    buffer = StringIO.new
    $stdout = buffer
    begin
      yield
    rescue StandardError
      nil
    end

    buffer.string
  ensure
    $stdout = original
  end

  describe ".pipeline" do
    it "passes both the task name and its title to a strict lambda" do
      seen = []
      runner = -> (name, title) { seen << [name, title] }

      silently { described_class.pipeline([%w[a:task first], %w[b:task second]], &runner) }

      expect(seen).to(eq([["a:task", "first"], ["b:task", "second"]]))
    end

    it "numbers the steps continuously across a second phase" do
      runner = -> (_name, _title) { }
      _, output = silently do
        described_class.pipeline([%w[a one]], total: 3, &runner)
        described_class.pipeline([%w[b two], %w[c three]], offset: 1, total: 3, &runner)
      end

      expect(output).to(include("[1/3] one").and(include("[2/3] two")).and(include("[3/3] three")))
    end

    it "returns a timing for every step" do
      result, = silently { described_class.pipeline([%w[a one], %w[b two]]) { |_, _| } }

      expect(result.map(&:first)).to(eq(%w[one two]))
      expect(result.map(&:last)).to(all(be_a(Float)))
    end

    it "reports which step failed and re-raises" do
      runner = -> (_name, _title) { raise IOError, "disk gone" }

      expect { silently { described_class.pipeline([%w[a one]], &runner) } }.to(raise_error(IOError))
    end

    it "names the failing step and the error in the output" do
      runner = -> (_name, _title) { raise IOError, "disk gone" }

      output = output_of { described_class.pipeline([%w[a one]], &runner) }

      expect(output).to(include("one").and(include("IOError")).and(include("disk gone")))
    end
  end

  describe ".slowest" do
    it "ranks the steps by time spent" do
      _, output = silently { described_class.slowest([["quick", 0.1], ["slow", 9.0], ["middling", 1.0]]) }

      expect(output.index("slow")).to(be < output.index("middling"))
      expect(output.index("middling")).to(be < output.index("quick"))
    end

    it "prints nothing when there is nothing to rank" do
      _, output = silently { described_class.slowest([]) }

      expect(output).to(be_empty)
    end
  end

  describe ".tuning_report" do
    it "warns when the server caps parallelism below the available cores" do
      _, output = silently do
        described_class.tuning_report(
          cores: 18,
          parallel_workers: 8,
          work_mem: "1024MB",
          maintenance_work_mem: "4096MB",
          capped_by_server: true,
          max_worker_processes: 8
        )
      end

      expect(output).to(include("max_worker_processes = 8").and(include("postgresql.conf")))
    end

    it "stays quiet when the machine is fully usable" do
      _, output = silently do
        described_class.tuning_report(
          cores: 8,
          parallel_workers: 6,
          work_mem: "512MB",
          maintenance_work_mem: "2048MB",
          capped_by_server: false,
          max_worker_processes: 32
        )
      end

      expect(output).not_to(include("postgresql.conf"))
    end
  end
end
