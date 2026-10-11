# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Media clips", :no_auth do
  let(:root) { Pathname(Dir.mktmpdir) }

  before do
    %w[listening/audio word_clips/audio].each { |folder| root.join(folder).mkpath }
    root.join("word_clips/audio/abc123.mp3").binwrite("ID3")
    root.join("listening/audio/common_voice_1.mp3").binwrite("ID3")
    allow(AppData).to(receive(:media_path)) { |relative| root.join(relative) }
  end

  after { FileUtils.remove_entry(root) }

  it "serves a cut word and a listening clip from their own folders" do
    get("/word_clips/abc123")
    expect(response).to(have_http_status(:ok))
    expect(response.media_type).to(eq("audio/mpeg"))

    get("/listening/clips/common_voice_1")
    expect(response).to(have_http_status(:ok))
  end

  it "refuses anything outside the clip folders" do
    get("/word_clips/common_voice_1")
    expect(response).to(have_http_status(:not_found))

    get("/word_clips/..%2Fsecret")
    expect(response).to(have_http_status(:not_found))
  end
end
