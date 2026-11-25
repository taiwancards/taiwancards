# frozen_string_literal: true

module NoticeDrafts
  PUBLISHED_LINE = "請依醫師指示按時服藥。"
  DRAFT_LINE = "這是一份還沒確認的草稿。"

  def notice_drafts_path = Rails.root.join("tmp", "notice_drafts_#{Process.pid}.json")

  def stub_notice_drafts
    path = notice_drafts_path
    entries = [
      notice_entry("ready", "health", PUBLISHED_LINE),
      notice_entry("unsure", "school", DRAFT_LINE, draft: true)
    ]
    path.write(JSON.generate("notices" => entries))
    stub_const("Huayu::TaiwanNotices::PATH", path)
    Huayu::TaiwanNotices.reset!
  end

  def with_notice_drafts
    stub_notice_drafts
    yield
  ensure
    unstub_notice_drafts
  end

  def unstub_notice_drafts
    notice_drafts_path.delete if notice_drafts_path.exist?
    Huayu::TaiwanNotices.reset!
  end

  private

  def notice_entry(id, situation, line, draft: false)
    {
      "id" => id,
      "kind" => "藥袋",
      "situation" => situation,
      "draft" => draft,
      "position" => draft ? 2 : 1,
      "style" => "form",
      "title" => {"zh" => "藥袋", "en" => "Medicine bag", "ru" => "Пакет с лекарством"},
      "about" => {"en" => "About.", "ru" => "О документе."},
      "fields" => [
        {
          "label" => {"zh" => "姓名", "en" => "Name", "ru" => "Имя"},
          "value" => "王小明",
          "note" => {"en" => "Yours.", "ru" => "Ваше."}
        }
      ],
      "items" => [{"mark" => "", "zh" => line, "en" => "A line.", "ru" => "Строка."}]
    }
  end
end

RSpec.configure { |config| config.include(NoticeDrafts) }
