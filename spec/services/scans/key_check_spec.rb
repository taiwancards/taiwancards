# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scans::KeyCheck do
  let(:key) { Scans::ApiKey.new(good_scan_key, "stored") }

  before { allow(described_class).to(receive(:call).and_call_original) }

  def client(&answer)
    models = Object.new
    models.define_singleton_method(:retrieve) { |model| answer.call(model) }
    Struct.new(:models).new(models)
  end

  it "asks for the configured model, which costs nothing" do
    asked = nil

    expect(described_class.call(key, client: client { |model| asked = model })).to(eq(:ok))
    expect(asked).to(eq(Scans::Settings.model))
  end

  {
    [Anthropic::Errors::AuthenticationError, 401] => :rejected,
    [Anthropic::Errors::PermissionDeniedError, 403] => :rejected,
    [Anthropic::Errors::NotFoundError, 404] => :no_model,
    [Anthropic::Errors::RateLimitError, 429] => :unreachable,
    [Anthropic::Errors::InternalServerError, 500] => :unreachable
  }.each do |(klass, status), outcome|
    it "reads #{status} as #{outcome}" do
      expect(described_class.call(key, client: client { raise provider_error(klass, status) })).to(eq(outcome))
    end
  end

  it "reads a timeout as unreachable" do
    timeout = Anthropic::Errors::APITimeoutError.new(url: URI("https://example.invalid"))

    expect(described_class.call(key, client: client { raise timeout })).to(eq(:unreachable))
  end

  it "builds a client with a short timeout and no retries" do
    built = nil
    allow(Anthropic::Client).to(
      receive(:new).and_wrap_original { |original, **options|
        built = options
        original.call(**options)
      }
    )
    allow_any_instance_of(Anthropic::Resources::Models).to(receive(:retrieve).and_return(nil))

    described_class.call(key)

    expect(built).to(include(timeout: described_class::TIMEOUT, max_retries: 0))
  end
end
