# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Textbook audio" do
  let(:name) { "B1L01-I-01.mp3" }
  let(:clip) { AppData.media_path(File.join(TextbookLesson::AUDIO_DIR, name)) }

  before do
    clip.dirname.mkpath
    clip.binwrite("ID3 stand-in for a real clip")
  end

  after { clip.delete if clip.exist? }

  it "gives a signed-out visitor nothing, even with the exact link", :no_auth do
    get(textbook_audio_path(name))

    expect(response).to(have_http_status(:not_found))
    expect(response.body).not_to(include("ID3"))
  end

  it "gives a signed-in user without restricted access nothing" do
    get(textbook_audio_path(name))

    expect(response).to(have_http_status(:not_found))
  end

  it "serves the clip to a user who has restricted access" do
    sign_in(create(:user, restricted_content: true))

    get(textbook_audio_path(name))

    expect(response).to(have_http_status(:ok))
    expect(response.media_type).to(eq("audio/mpeg"))
    expect(response.body).to(include("ID3"))
  end

  it "lets no shared cache keep a copy" do
    sign_in(create(:user, restricted_content: true))

    get(textbook_audio_path(name))

    expect(response.headers["cache-control"]).to(include("private"))
    expect(response.headers["cache-control"]).not_to(include("public"))
  end

  it "answers the second request from the browser cache" do
    sign_in(create(:user, restricted_content: true))
    get(textbook_audio_path(name))

    get(textbook_audio_path(name), headers: {"if-none-match" => response.headers["etag"]})

    expect(response).to(have_http_status(:not_modified))
  end

  it "answers 404 for a name that is not on disk" do
    sign_in(create(:user, restricted_content: true))

    get(textbook_audio_path("B9L99-Z-99.mp3"))

    expect(response).to(have_http_status(:not_found))
  end

  it "has no route for a name that could climb out of the directory" do
    sign_in(create(:user, restricted_content: true))

    get("/textbook/audio/..%2F..%2Fconfig%2Fdatabase.yml")

    expect(response).to(have_http_status(:not_found))
  end

  context("when the clip lives only in the runtime bucket") do
    let(:signed) { "https://bucket.example/media/audio/textbook/#{name}?X-Amz-Expires=900" }

    before do
      clip.delete if clip.exist?
      create(:textbook_lesson, vocabulary: [{"name" => "學校", "audio" => name}])
      TextbookLesson.forget_audio_names!
      allow(Storage::Bucket).to(receive(:configured?).and_return(true))
      allow(Storage::Bucket).to(receive(:runtime).and_return(instance_double(Storage::Bucket, link: signed)))
    end

    after { TextbookLesson.forget_audio_names! }

    it "still gives a signed-out visitor nothing", :no_auth do
      get(textbook_audio_path(name))

      expect(response).to(have_http_status(:not_found))
    end

    it "hands a permitted user a link no cache may keep" do
      sign_in(create(:user, restricted_content: true))

      get(textbook_audio_path(name))

      expect(response).to(redirect_to(signed))
      expect(response.headers["cache-control"]).to(eq("private, no-store"))
    end

    it "answers 404 for a name the lessons never mention" do
      sign_in(create(:user, restricted_content: true))

      get(textbook_audio_path("B9L99-Z-99.mp3"))

      expect(response).to(have_http_status(:not_found))
    end
  end

  it "keeps the clips off the public file server" do
    expect(Rails.root.join("public/audio")).not_to(exist)
  end

  it "points the lesson page at the gated route, never at a static path" do
    lesson = create(:textbook_lesson, vocabulary: [{"name" => "學校", "audio" => name}])

    expect(lesson.audio_url(lesson.vocabulary.first)).to(eq("/textbook/audio/#{name}"))
  end
end
