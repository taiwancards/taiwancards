# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The progress section" do
  it "carries the summary, the history and the collected data under one address" do
    [progress_path, progress_history_path, progress_data_path].each do |path|
      get(path)

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include(I18n.t("progress.title")))
    end
  end

  it "reaches every tab from every tab" do
    get(progress_path)

    [progress_history_path, progress_data_path].each do |path|
      expect(response.body).to(include("href=\"#{path}\""))
    end
  end

  it "counts what is stored about the user on the data tab" do
    lexeme = create(:lexeme, kind: :character, text: "水", meanings: {"en" => "water"})
    Lexemes::Activator.new.call(lexeme)

    get(progress_data_path)

    expect(response.body).to(include(I18n.t("auth.data_rows.memories")))
    expect(response.body).to(include(I18n.t("auth.data_excluded")))
  end

  it "no longer answers on the addresses it replaced" do
    %w[/stats /history].each do |path|
      get(path)

      expect(response).to(have_http_status(:not_found))
    end
  end

  it "offers one menu entry instead of two" do
    get(desk_path)

    expect(response.body).to(include(I18n.t("nav.progress")))
    expect(response.body).to(include("href=\"#{progress_path}\""))
  end
end
