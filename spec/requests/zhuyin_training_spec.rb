# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Zhuyin trainer" do
  it "opens on the first block with a way out already visible" do
    get("/practice/zhuyin-trainer")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("zhuyin_trainer.blocks.labial")))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("zhuyin_trainer.exit_hint"))))
  end

  it "puts no latin whatsoever into the drill items" do
    get("/practice/zhuyin-trainer")

    payload = response.body[/data-zhuyin-trainer-items-value="([^"]*)"/, 1]
    expect(payload).to(be_present)

    symbols = JSON.parse(CGI.unescape_html(payload)).flat_map { |item| item["options"] }
    expect(symbols).to(all(match(/\A[\u3105-\u312F]\z/)))
  end

  it "records results and reports progress" do
    post(
      "/practice/zhuyin-trainer",
      params: {results: [{symbol: "ㄅ", correct: true, elapsed_ms: 800}]},
      as: :json
    )

    expect(response).to(have_http_status(:ok))
    expect(@authenticated_user.reload.zhuyin_mastery.dig("ㄅ", "streak")).to(eq(1))
  end

  it "ignores a symbol that is not part of the system" do
    post("/practice/zhuyin-trainer", params: {results: [{symbol: "Z", correct: true}]}, as: :json)

    expect(@authenticated_user.reload.zhuyin_mastery).to(be_empty)
  end

  it "ticks the roadmap step once every symbol is mastered" do
    mastery = Huayu::ZhuyinTrainer::ALL.index_with { {"streak" => 3} }
    @authenticated_user.update_zhuyin_mastery!(mastery)

    post(
      "/practice/zhuyin-trainer",
      params: {results: [{symbol: "ㄅ", correct: true, elapsed_ms: 700}]},
      as: :json
    )

    expect(@authenticated_user.reload.path_steps_done).to(include("zhuyin"))
  end

  it "is reachable from the roadmap, which is where START puts a beginner" do
    expect(desk_start_path).to(eq(roadmap_path))

    get(roadmap_path)
    expect(response.body).to(include(zhuyin_training_path))
  end

  it "labels every option button with the direction its arrow key must hit" do
    get("/practice/zhuyin-trainer")

    %w[up left right down].each do |direction|
      expect(response.body).to(include("data-direction=\"#{direction}\""))
    end
  end

  it "keeps the option buttons in the order the cross layout implies" do
    get("/practice/zhuyin-trainer")

    order = %w[up left right down].map { |d| response.body.index("data-direction=\"#{d}\"") }
    expect(order).to(eq(order.sort))
  end

  it "does not share a name with the pinyin matching drill" do
    expect(I18n.t("nav.zhuyin_trainer")).not_to(eq(I18n.t("nav.sounds_drill")))
    expect(I18n.t("zhuyin_trainer.title")).not_to(eq(I18n.t("practice.drill.title")))

    %i[en ru].each do |locale|
      expect(I18n.t("nav.zhuyin_trainer", locale:)).not_to(eq(I18n.t("nav.sounds_drill", locale:)))
    end
  end

  it "says on the page what makes it different" do
    get("/practice/zhuyin-trainer")

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("zhuyin_trainer.lede"))))
  end
end
