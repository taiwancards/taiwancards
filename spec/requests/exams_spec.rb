# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Exams" do
  let(:paper) { Huayu::TocflPapers.find("a-set1-listening") }

  context("with restricted access") do
    let!(:owner) { sign_in(create(:user, restricted_content: true)) }

    it "lists the official papers by band" do
      get("/exams")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("/exams/#{paper.slug}"))
    end

    it "shows an answer sheet with one row per question" do
      get("/exams/#{paper.slug}")

      expect(response).to(have_http_status(:ok))
      expect(response.body.scan(/name="answers\[\d+\]"/).uniq.size).to(eq(paper.count))
    end

    it "marks a full sheet against the official key and keeps the score" do
      answers = paper.numbers.to_h { |number| [number.to_s, paper.answer(number)] }

      post("/exams/#{paper.slug}", params: {answers:})

      expect(response.body).to(include("#{paper.count} / #{paper.count}"))
      expect(CourseCompletion.find_by(user: owner, slug: "tocfl:#{paper.slug}").score).to(eq(paper.count))
    end

    it "marks a wrong answer wrong and shows the expected letter" do
      wrong = paper.answer(1) == "A" ? "B" : "A"

      post("/exams/#{paper.slug}", params: {answers: {"1" => wrong}})

      expect(response.body).to(include("0 / #{paper.count}"))
    end

    it "serves the paper as a pdf" do
      get("/exams/#{paper.slug}/paper")

      expect(response).to(have_http_status(:ok))
      expect(response.media_type).to(eq("application/pdf"))
    end

    context("with the real media on this machine") do
      around do |example|
        previous = ENV["MEDIA_ROOT"]
        ENV["MEDIA_ROOT"] = Rails.root.join("media").to_s
        example.run
        previous.nil? ? ENV.delete("MEDIA_ROOT") : ENV["MEDIA_ROOT"] = previous
      end

      it "serves a listening clip that belongs to the paper" do
        get("/exams/#{paper.slug}/audio", params: {name: paper.clips.first})

        expect(response).to(have_http_status(:ok))
        expect(response.media_type).to(eq("audio/mpeg"))
      end

      it "refuses a path that climbs out of the clip folder" do
        get("/exams/#{paper.slug}/audio", params: {name: "../../../../etc/passwd"})

        expect(response).to(have_http_status(:not_found))
      end
    end

    it "renders an extracted question with its options instead of bare letters" do
      with_items = Huayu::TocflPapers.all.find { |row| row.interactive.positive? }
      item = with_items.items.first

      get("/exams/#{with_items.slug}")

      expect(response.body).to(include(CGI.escapeHTML(item.stem)))
      expect(response.body).to(include(CGI.escapeHTML(item.options.values.first)))
    end

    it "keeps every extracted question answerable and unambiguous" do
      Huayu::TocflPapers.all.flat_map { |row| row.items.map { |item| [row, item] } }.each do |row, item|
        key = row.answer(item.number)

        expect(item.options).to(include(key), "#{row.slug} ##{item.number}: key #{key} is not among the options")
        expect(item.options.values.uniq.size).to(eq(item.options.size))
        expect(item.stem).to(match(/[　\s]{4,}|＿|_{2,}/), "#{row.slug} ##{item.number}: no gap in the stem")
      end
    end

    it "answers with not found for a paper that does not exist" do
      get("/exams/no-such-paper")

      expect(response).to(have_http_status(:not_found))
    end
  end

  it "keeps the whole section away from everybody else" do
    sign_in(create(:user))

    get("/exams")
    expect(response).to(redirect_to(root_path))

    get("/exams/#{paper.slug}/paper")
    expect(response).to(redirect_to(root_path))
  end
end
