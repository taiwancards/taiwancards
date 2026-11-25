# frozen_string_literal: true

require "anthropic"

ENV.delete("ANTHROPIC_API_KEY")
ENV.delete("SCAN_MODEL")

module ScanHelpers
  FakeUsage = Struct.new(:input_tokens, :output_tokens, :cache_read_input_tokens, :cache_creation_input_tokens)
  FakeBlock = Struct.new(:type, :text)
  FakeMessage = Struct.new(:model, :stop_reason, :content, :usage)

  class FakeClient
    attr_reader :requests

    def initialize(&respond)
      @respond = respond
      @requests = []
    end

    def beta = self

    def messages = self

    def create(**params)
      @requests << params
      @respond.call(params)
    end
  end

  def scan_photo(name = "page.jpg", type: "image/jpeg")
    Rack::Test::UploadedFile.new(file_fixture("scans/#{name}"), type)
  end

  def provider_reply(lines:, legibility: "clear", stop_reason: :end_turn, model: "claude-opus-5-5")
    text = {legibility:, lines:}.to_json
    FakeMessage.new(model, stop_reason, [FakeBlock.new(:text, text)], FakeUsage.new(1500, 200, 0, 0))
  end

  def provider_error(klass, status)
    klass.new(
      url: URI("https://example.invalid/v1/messages"),
      status:,
      headers: {},
      body: nil,
      request: nil,
      response: nil
    )
  end

  def good_scan_key = "sk-ant-api03-#{"a" * 80}-#{"Zz9_" * 4}"

  def provider_answers(outcome) = allow(Scans::KeyCheck).to(receive(:call).and_return(outcome))

  def with_scan_key(&)
    previous = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key-not-real"
    yield
  ensure
    previous.nil? ? ENV.delete("ANTHROPIC_API_KEY") : ENV["ANTHROPIC_API_KEY"] = previous
  end
end

module ScanJobTestAdapter
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new
end

RSpec.configure do |config|
  config.include(ScanHelpers)
  config.include(ScanJobTestAdapter)

  config.before do
    ScanJob.recognizer = -> { raise "specs must stub ScanJob.recognizer" }
    allow(Scans::KeyCheck).to(receive(:call)) { raise "specs must stub Scans::KeyCheck.call" }
  end
end
