# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Importing a deck from another app" do
  def word(text, pinyin, kind: :word) = create(:lexeme, kind:, text:, readings: {"pinyin" => pinyin})

  def upload(body, name = "pleco.txt")
    file = Tempfile.new(["import", File.extname(name)])
    file.write(body)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/plain", original_filename: name)
  end

  it "offers the import tab with instructions for each app" do
    get(new_desk_path(tab: "import"))

    expect(response.body).to(include(I18n.t("imports.sources.pleco.steps"), I18n.t("imports.sources.anki.steps")))
  end

  it "previews an upload without saving anything" do
    word("學校", "xuéxiào")
    word("資訊", "zīxùn")

    expect {
      post(
        desk_import_preview_path,
        params: {
          source: "pleco",
          file: upload("学校[學校]\txue2xiao4\tschool\n信息\txin4xi1\tinfo\n你好嗎\tni3hao3ma5\thi\n")
        }
      )
    }
      .not_to(change(Collection, :count))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("學校", "資訊", I18n.t("imports.preview.china"), "你好嗎"))
  end

  it "creates the deck from the checked words, the choices and the Taiwanese swaps" do
    school = word("學校", "xuéxiào")
    hair = word("髮", "fǎ", kind: :character)
    info = word("資訊", "zīxùn")

    post(
      desk_import_path,
      params: {
        selection: Collections::Selection.pack([school.id]),
        picks: {"0" => hair.id.to_s},
        swaps: [info.id.to_s],
        name: "My Pleco words",
        facets: %w[recognition]
      }
    )

    desk = Collection.desks_for(current_user).find_by(name: "My Pleco words")
    expect(response).to(redirect_to(my_desk_path(desk)))
    expect(desk.lexemes).to(contain_exactly(school, hair, info))
    expect(desk.study_facets).to(eq(%w[recognition]))
  end

  it "leaves out words the learner already has when asked to" do
    school = word("學校", "xuéxiào")
    teacher = word("老師", "lǎoshī")
    LexemeMemory.create!(
      lexeme: school,
      user: current_user,
      facet: :recognition,
      activated_at: Time.current,
      state: :review
    )

    post(
      desk_import_path,
      params: {selection: Collections::Selection.pack([school.id, teacher.id]), skip_covered: "1", name: "Fresh"}
    )

    expect(Collection.desks_for(current_user).find_by(name: "Fresh").lexemes).to(eq([teacher]))
  end

  it "sends the learner back when the file holds no Chinese" do
    post(desk_import_preview_path, params: {source: "anki", file: upload("front\tback\n", "anki.txt")})

    expect(response).to(redirect_to(new_desk_path(tab: "import")))
    expect(flash[:alert]).to(eq(I18n.t("imports.unreadable")))
  end

  it "refuses an unknown source" do
    post(desk_import_preview_path, params: {source: "duolingo", text: "學校"})

    expect(flash[:alert]).to(eq(I18n.t("imports.pick_source")))
  end
end
