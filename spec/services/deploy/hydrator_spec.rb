# frozen_string_literal: true

require "rails_helper"

RSpec.describe Deploy::Hydrator do
  let(:script) { Rails.root.join("bin/distribute").read }
  let(:scratch) { Pathname(Dir.mktmpdir) }

  after { scratch.rmtree }

  def runtime_keys(list)
    script[/^#{list}=\((.*?)\)/m, 1].to_s.scan(/"[^"|]+\|([^"]+)"/).flatten
  end

  it "brings into the image every single file the runtime target uploads" do
    keys = runtime_keys("RUNTIME_FILES") + runtime_keys("RUNTIME_ARCHIVES")
    expect(keys).not_to(be_empty)

    uncovered = keys.reject { |key| described_class::PREFIXES.keys.any? { |prefix| key.start_with?(prefix) } }
    expect(uncovered).to(be_empty)
  end

  it "lays the word clip manifest where the running app reads it" do
    objects = {"media/word_clips/manifest.json" => "{\"clips\":{}}"}
    bucket = instance_double(Storage::Bucket)
    allow(bucket).to(receive(:each_object)) do |prefix, &block|
      objects.each { |key, body| block.call(key, body.bytesize) if key.start_with?(prefix) }
    end

    allow(bucket).to(receive(:download)) do |key, path|
      path.dirname.mkpath
      path.write(objects.fetch(key))
    end

    allow(Storage::Bucket).to(receive_messages(configured?: true, runtime: bucket))

    described_class.new(io: StringIO.new, data_root: scratch.join("data"), media_root: scratch.join("media")).call

    expect(scratch.join("media/word_clips/manifest.json").read).to(eq("{\"clips\":{}}"))
  end
end
