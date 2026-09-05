# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offline::Pool do
  let(:renderer) { instance_double(Offline::Renderer) }

  def page(path, locale)
    "<html><head><title>#{path}</title></head><body><main class=\"max-w-3xl\"><p>#{locale} #{path}</p></main></body></html>"
  end

  def pids_of(fragments) = fragments.values.map { |fragment| fragment["m"].split(":").last }.uniq

  describe "with a single worker" do
    subject(:pool) { described_class.new(workers: 1, renderer: renderer) }

    before { allow(renderer).to(receive(:call)) { |path, locale| page(path, locale) } }

    it "renders in the calling process, in the order asked" do
      fragments, refused = pool.render(%w[/tones /hanzi /cangjie], :en)

      expect(fragments.keys).to(eq(%w[/tones /hanzi /cangjie]))
      expect(fragments.dig("/hanzi", "m")).to(eq("<p>en /hanzi</p>"))
      expect(refused).to(be_empty)
      expect(pool).not_to(be_parallel)
    end

    it "reports how far it got after every slice" do
      seen = []
      pool.render((1..90).map { |n| "/p#{n}" }, :ru) { |done| seen << done }

      expect(seen).to(eq([40, 80, 90]))
    end
  end

  describe "with several workers" do
    subject(:pool) { described_class.new(workers: 3, renderer: renderer, command: OfflineFakeWorker::COMMAND) }

    after { pool.close }

    it "spreads the pages over the children and keeps the order asked" do
      paths = (1..300).map { |n| "/p#{n}" }
      fragments, refused = pool.render(paths, :ru)

      expect(fragments.keys).to(eq(paths))
      expect(fragments.values.map { |fragment| fragment["m"] }).to(all(start_with("ru:")))
      expect(pids_of(fragments).size).to(be > 1)
      expect(refused).to(be_empty)
    end

    it "gathers the refusals from every child" do
      paths = (1..100).map { |n| (n % 10).zero? ? "/refuse#{n}" : "/p#{n}" }
      fragments, refused = pool.render(paths, :en)

      expect(fragments.size).to(eq(90))
      expect(refused.size).to(eq(10))
      expect(refused).to(all(match(%r{\A/en/refuse\d+ answered 302\z})))
    end

    it "reports progress as slices come back" do
      seen = []
      pool.render((1..100).map { |n| "/p#{n}" }, :en) { |done| seen << done }

      expect(seen.size).to(eq(3))
      expect(seen).to(eq(seen.sort))
      expect(seen.last).to(eq(100))
    end

    it "raises instead of losing pages when a child dies" do
      expect { pool.render(%w[/ok /die], :en) }.to(raise_error(described_class::Error, /died/))
    end
  end

  describe ".workers" do
    it "takes the count from WORKERS when it is given" do
      expect(described_class.workers("7")).to(eq(7))
    end

    it "falls back to the performance cores of this machine" do
      expect(described_class.workers(nil)).to(eq(Install::Hardware.workers))
    end
  end
end
