# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Zhuyin theory" do
  it "offers a drill for each group of symbols it teaches" do
    get("/en/practice/zhuyin?part=initials")

    expect(response).to(have_http_status(:ok))
    Huayu::ZhuyinTrainer.blocks_in("initials").each do |block|
      expect(response.body).to(include("block=#{block[:key]}"), "no drill for #{block[:key]}")
      expect(response.body).to(include(I18n.t("practice.blocks.#{block[:key]}.title")))
    end
  end

  it "does the same for the finals" do
    get("/en/practice/zhuyin?part=finals")

    Huayu::ZhuyinTrainer.blocks_in("finals").each do |block|
      expect(response.body).to(include("block=#{block[:key]}"), "no drill for #{block[:key]}")
    end
  end

  it "leaves the compound finals without a drill of their own" do
    get("/en/practice/zhuyin?part=finals")

    expect(response.body).to(include(I18n.t("practice.blocks.compound.title")))
    expect(response.body).not_to(include("block=compound"))
  end
end
