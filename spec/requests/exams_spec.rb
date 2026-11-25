# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Exams" do
  let(:paper) { Huayu::TocflPapers.find("a-set1-listening") }
  let(:unbundled) { Huayu::TocflPapers.find("b-set5-reading") }
  let(:band_c) { Huayu::TocflPapers.find("c-set1-reading") }
  let(:manifest) do
    {
      "bundles" => {
        "a-set1-listening" => {
          "digest" => "abc123def456",
          "minutes" => 60,
          "count" => 50,
          "levels" => ["Level 1", "Level 2"],
          "audio" => "mock_BandA_mp3_en",
          "clips" => ["001.mp3"],
          "parts" => [{"id" => 1, "title" => "看圖回答", "count" => 25, "plays" => 2}],
          "scale" => {
            "max" => 80,
            "table" => [[0, 0], [37, 59], [50, 80]],
            "thresholds" => [{"level" => "Level 1", "min" => 41}]
          },
          "papers" => {"base" => "ls_mock_test_BandA_en_t.pdf", "vi" => "ls_mock_test_BandA_vie_t.pdf"}
        },
        "c-set1-reading" => {
          "digest" => "c0ffee000000",
          "minutes" => 60,
          "count" => 50,
          "levels" => ["Level 5", "Level 6"],
          "clips" => [],
          "parts" => [{"id" => 1, "title" => nil, "count" => 20, "plays" => nil}],
          "scale" => nil,
          "papers" => {}
        }
      }
    }
  end

  before do
    allow(Huayu::TocflBundles::MANIFEST).to(receive(:value).and_return(manifest))
    Huayu::TocflBundles.reset!
  end

  after { Huayu::TocflBundles.reset! }

  def full_sheet = paper.numbers.to_h { |number| [number.to_s, paper.answer(number)] }

  context("as a guest", :no_auth) do
    it "lists the papers that have a bundle, from a shareable page without a session" do
      get("/exams")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("/exams/#{paper.slug}"))
      expect(response.body).not_to(include("/exams/#{unbundled.slug}"))
      expect(response.body).to(include("/exams/#{band_c.slug}", "Band C"))
      expect(response.body).to(include("國家華語測驗推動工作委員會"))
      expect(response.body).to(include("Part 1 · 看圖回答 · 25 questions · heard twice"))
      expect(response.headers["Cache-Control"]).to(include("public", "s-maxage="))
      expect(response.headers["Set-Cookie"]).to(be_blank)
    end

    it "serves the player with the versioned bundle address and no place to send a result" do
      get("/exams/#{paper.slug}")

      expect(response).to(have_http_status(:ok))
      expect(response.headers["Cache-Control"]).to(include("public", "s-maxage="))
      expect(response.headers["Set-Cookie"]).to(be_blank)
      player = Nokogiri::HTML(response.body).at("[data-controller='exam-player']")
      expect(player["data-exam-player-bundle-value"]).to(
        end_with("/tocfl_papers/#{paper.slug}/bundle.json?v=abc123def456")
      )
      expect(player["data-exam-player-media-value"]).to(end_with("/tocfl_official/"))
      expect(player["data-exam-player-record-value"]).to(be_nil)
      expect(JSON.parse(player["data-exam-player-thresholds-value"])).to(eq([{"level" => "Level 1", "min" => 41}]))
      expect(response.body).to(include("/tocfl_pdf/ls_mock_test_BandA_en_t.pdf"))
      expect(JSON.parse(player["data-exam-player-strings-value"])).to(include("finish", "scale", "level_n"))
    end

    it "answers not found for a paper whose bundle is not published yet, or that does not exist" do
      get("/exams/#{unbundled.slug}")
      expect(response).to(have_http_status(:not_found))

      get("/exams/no-such-paper")
      expect(response).to(have_http_status(:not_found))
    end

    it "keeps nothing on the server for a guest's attempt" do
      expect { post("/exams/#{paper.slug}/result", params: {answers: full_sheet}, as: :json) }
        .not_to(change(CourseCompletion, :count))
    end

    it "still keeps the textbook and the reading room restricted" do
      get("/textbook")
      expect(response).not_to(have_http_status(:ok))

      get("/stories")
      expect(response).not_to(have_http_status(:ok))
    end
  end

  context("when signed in") do
    let!(:learner) { sign_in(create(:user)) }

    it "renders a private page that knows where to record the result" do
      get("/exams/#{paper.slug}")

      expect(response.headers["Cache-Control"]).not_to(include("public"))
      player = Nokogiri::HTML(response.body).at("[data-controller='exam-player']")
      expect(player["data-exam-player-record-value"]).to(end_with("/exams/#{paper.slug}/result"))
    end

    it "re-marks the sheet against the server's own key and keeps the best score" do
      sheet = full_sheet.merge("1" => paper.answer(1) == "A" ? "B" : "A", "2" => "Z")

      post("/exams/#{paper.slug}/result", params: {answers: sheet, score: 50}, as: :json)

      expect(response).to(have_http_status(:ok))
      expect(response.parsed_body).to(
        include("score" => paper.count - 2, "total" => paper.count, "best" => paper.count - 2)
      )
      expect(CourseCompletion.find_by(user: learner, slug: "tocfl:#{paper.slug}").score).to(eq(paper.count - 2))

      post("/exams/#{paper.slug}/result", params: {answers: {"1" => paper.answer(1)}}, as: :json)

      expect(response.parsed_body).to(include("score" => 1, "best" => paper.count - 2))
    end

    it "shows the recorded best on the index" do
      CourseCompletion.record(user: learner, slug: "tocfl:#{paper.slug}", score: 37, total: 50)

      get("/exams")

      expect(response.body).to(include("37/50 · 59/80"))
      expect(response.headers["Cache-Control"]).not_to(include("public"))
    end

    it "still keeps the textbook and the reading room for restricted accounts" do
      get("/textbook")
      expect(response).to(redirect_to(root_path))

      get("/stories")
      expect(response).to(redirect_to(root_path))
    end
  end
end
