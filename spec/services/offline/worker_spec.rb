# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offline::Worker do
  subject(:worker) { described_class.new(renderer: renderer) }

  let(:renderer) { instance_double(Offline::Renderer) }

  def page(path, locale)
    "<html><head><title>#{path}</title></head><body><main class=\"max-w-3xl\"><p>#{locale} #{path}</p></main></body></html>"
  end

  before do
    allow(renderer).to(receive(:call)) do |path, locale|
      raise Offline::Renderer::Refused, "/#{locale}#{path} answered 302" if path == "/desk"

      path == "/bare" ? "<html><body>no main</body></html>" : page(path, locale)
    end
  end

  it "renders the paths it is handed, in that order" do
    answer = worker.perform("ru", %w[/tones /hanzi])

    expect(answer.fetch("fragments").keys).to(eq(%w[/tones /hanzi]))
    expect(answer.dig("fragments", "/hanzi")).to(eq({"t" => "/hanzi", "w" => "narrow", "m" => "<p>ru /hanzi</p>"}))
    expect(answer.fetch("refused")).to(be_empty)
  end

  it "keeps the refusal instead of the page" do
    answer = worker.perform("en", %w[/hanzi /desk])

    expect(answer.fetch("fragments").keys).to(eq(["/hanzi"]))
    expect(answer.fetch("refused")).to(eq(["/en/desk answered 302"]))
  end

  it "leaves out a page without a main element" do
    expect(worker.perform("en", %w[/bare /hanzi]).fetch("fragments").keys).to(eq(["/hanzi"]))
  end

  it "serves jobs over a pair of pipes until the feed closes" do
    jobs_reader, jobs_writer = IO.pipe
    answers_reader, answers_writer = IO.pipe
    Offline::Frames.write(jobs_writer, {"locale" => "en", "paths" => ["/hanzi"]})
    Offline::Frames.write(jobs_writer, {"locale" => "ru", "paths" => ["/desk"]})
    jobs_writer.close

    worker.call(jobs_reader, answers_writer)
    answers_writer.close

    expect(Offline::Frames.read(answers_reader).fetch("fragments").keys).to(eq(["/hanzi"]))
    expect(Offline::Frames.read(answers_reader).fetch("refused")).to(eq(["/ru/desk answered 302"]))
    expect(Offline::Frames.read(answers_reader)).to(be_nil)
  end
end
