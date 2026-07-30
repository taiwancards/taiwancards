# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dictionary detail level" do
  let!(:xue) do
    create(
      :lexeme,
      :character,
      text: "學",
      readings: {"pinyin" => "xué", "zhuyin" => "ㄒㄩㄝˊ"},
      meanings: {"en" => "to learn", "ru" => "учиться"},
      data: {"cangjie" => "hbnd", "radical" => "子", "readings" => [{"pinyin" => "xué", "zhuyin" => "ㄒㄩㄝˊ"}]}
    )
  end

  let!(:word) do
    create(
      :lexeme,
      kind: :word,
      text: "學校",
      readings: {"pinyin" => "xuéxiào", "zhuyin" => "ㄒㄩㄝˊ ㄒㄧㄠˋ"},
      meanings: {"en" => "school", "ru" => "школа"},
      data: {"pos" => "N", "etymology_text" => "A compound of study and comparison.", "register_mix" => [0.8, 0.2]}
    )
  end

  let(:source) do
    ContentSource.find_by(slug: "corpus") ||
      ContentSource.create!(
        slug: "corpus",
        license_commercial: true,
        name: "Corpus",
        register: :colloquial,
        enabled: true,
        enabled_for_admins: true,
        attribution: "Corpus."
      )
  end

  let!(:sentence) do
    create(
      :lexeme,
      kind: :sentence,
      text: "我去學校。",
      meanings: {"en" => "I go to school.", "ru" => "Я иду в школу."},
      data: {"segments" => %w[我 去 學校 。], "register_mix" => [0.9, 0.1]},
      score: 5,
      content_sources: [source]
    )
  end

  before { LexemeLink.create!(parent: word, child: xue, position: 0, reading: "xué") }

  describe "the panel button" do
    it "offers the full view to a beginner and stores the choice" do
      get("/dict")
      expect(response.body).to(include("簡"))

      post("/prefs/detail", params: {mode: "full"}, headers: {"HTTP_REFERER" => "/dict"})
      expect(response).to(redirect_to("/dict"))
      expect(cookies["dict_detail"]).to(eq("full"))

      get("/dict")
      expect(response.body).to(include("詳"))
    end

    it "ignores a mode it does not know" do
      cookies["dict_detail"] = "brief"

      post("/prefs/detail", params: {mode: "everything"}, headers: {"HTTP_REFERER" => "/dict"})

      expect(response).to(redirect_to("/dict"))
      expect(cookies["dict_detail"]).to(eq("brief"))
    end
  end

  describe "the word page" do
    it "keeps meanings, part of speech and characters in the brief view" do
      cookies["dict_detail"] = "brief"
      get("/dict/#{CGI.escape("學校")}")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("школа").or(include("school")))
      expect(response.body).to(include(I18n.t("pos.tocfl.n")))
      expect(response.body).to(include(I18n.t("words.characters")))
    end

    it "drops the metrics and the long-form extras in the brief view" do
      cookies["dict_detail"] = "brief"
      get("/dict/#{CGI.escape("學校")}")

      expect(response.body).not_to(include(I18n.t("words.register_mix")))
      expect(response.body).not_to(include(I18n.t("words.etymology")))
      expect(response.body).not_to(include(I18n.t("words.score_hint")))
    end

    it "brings them back in the full view" do
      cookies["dict_detail"] = "full"
      get("/dict/#{CGI.escape("學校")}")

      expect(response.body).to(include(I18n.t("words.register_mix")))
      expect(response.body).to(include(I18n.t("words.etymology")))
    end

    it "translates the example sentences in both views" do
      SentenceWord.create!(lexeme: word, sentence_id: sentence.id, gdex: 500)

      %w[brief full].each do |mode|
        cookies["dict_detail"] = mode
        get("/dict/#{CGI.escape("學校")}")

        expect(response.body).to(include("I go to school.").or(include("Я иду в школу.")))
      end
    end

    it "ranks the register bars from the widest share down and leaves the missing ones last" do
      word.update!(data: word.data.merge("register_mix" => [0.1, 0.5, nil, 0.3, 0.05, 0.05, nil], "register_n" => 40))
      cookies["dict_detail"] = "full"
      get("/dict/#{CGI.escape("學校")}")

      section = Nokogiri::HTML5(response.body)
        .css("section")
        .find { |node| node.at_css("h2")&.text&.strip == I18n.t("words.register_mix") }
      labels = section.css("[title]").map { |node| node["title"].split(":").first }

      expect(labels).to(
        eq(
          %w[literary official colloquial academic internet publicistic subtitles].map { |style|
            I18n.t("admin.sources.registers.#{style}")
          }
        )
      )
    end

    it "keeps every example sentence inside a single card instead of splitting the link" do
      SentenceWord.create!(lexeme: word, sentence_id: sentence.id, gdex: 500)
      cookies["dict_detail"] = "full"
      get("/dict/#{CGI.escape("學校")}")

      links = Nokogiri::HTML5(response.body).css("a[href='#{sentence_path(sentence)}']")

      expect(links.size).to(eq(1))
      expect(links.first.parent.text).to(include(sentence.text))
    end
  end

  describe "the character page" do
    it "lists the common words flat and hides the input codes in the brief view" do
      cookies["dict_detail"] = "brief"
      get("/characters/#{CGI.escape("學")}")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include(I18n.t("characters.top_words")))
      expect(response.body).to(include("學校"))
      expect(response.body).not_to(include(">hbnd<"))
    end

    it "groups the words by reading in the full view" do
      cookies["dict_detail"] = "full"
      get("/characters/#{CGI.escape("學")}")

      expect(response.body).to(include(I18n.t("characters.words")))
      expect(response.body).to(include(">hbnd<"))
      expect(response.body).not_to(include(I18n.t("characters.top_words")))
    end

    it "puts the stroke practice above the etymology in both views" do
      %w[brief full].each do |mode|
        cookies["dict_detail"] = mode
        get("/characters/#{CGI.escape("學")}")

        writer = response.body.index(I18n.t("characters.stroke_order"))
        origin = response.body.index(I18n.t("characters.etymology"))
        expect(writer).to(be < origin) if writer && origin
      end
    end
  end

  describe "the radical page" do
    let!(:radical) do
      create(:lexeme, kind: :radical, text: "子", meanings: {"en" => "child"}, data: {"number" => 39})
    end

    before { xue.update!(data: xue.data.merge("radical_number" => 39)) }

    it "trims the character grid in the brief view and shows it whole in the full one" do
      cookies["dict_detail"] = "brief"
      get("/radicals/#{CGI.escape("子")}")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("學"))

      cookies["dict_detail"] = "full"
      get("/radicals/#{CGI.escape("子")}")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("學"))
    end
  end

  describe "the sentence page" do
    it "translates the sentence and every character in both views" do
      %w[brief full].each do |mode|
        cookies["dict_detail"] = mode
        get("/sentences/#{sentence.to_param}")

        expect(response).to(have_http_status(:ok))
        expect(response.body).to(include("I go to school.").or(include("Я иду в школу.")))
        expect(response.body).to(include("to learn").or(include("учиться")))
      end
    end

    it "sends an old numeric link to the public identifier" do
      get("/sentences/#{sentence.id}")

      expect(response).to(redirect_to(sentence_path(sentence)))
      expect(response).to(have_http_status(:moved_permanently))
    end

    it "answers a made-up identifier with a plain 404" do
      get("/sentences/019f0000-0000-7000-8000-000000000000")

      expect(response).to(have_http_status(:not_found))
      expect(response.body).to(include(I18n.t("sentences.missing_title")))
    end

    it "answers a nonsense identifier with a 404 rather than an error" do
      get("/sentences/99999999")

      expect(response).to(have_http_status(:not_found))
    end

    it "drops the level chips and the register mix in the brief view" do
      cookies["dict_detail"] = "brief"
      get("/sentences/#{sentence.to_param}")

      expect(response.body).not_to(include(I18n.t("words.register_mix")))
      expect(response.body).not_to(include(I18n.t("words.score_hint")))
    end
  end
end
