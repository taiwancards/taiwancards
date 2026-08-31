# frozen_string_literal: true

require "rails_helper"

RSpec.describe Bulk do
  describe ".patch" do
    it "writes the values it is given" do
      one = create(:lexeme, kind: :word, text: "測試", score: 0.0)
      two = create(:lexeme, kind: :word, text: "考試", score: 0.0)

      touched = described_class.patch(
        target: "lexemes",
        columns: {"score" => "float8"},
        rows: [[one.id, 12.5], [two.id, 33.25]]
      )

      expect(touched).to(eq(2))
      expect(one.reload.score).to(eq(12.5))
      expect(two.reload.score).to(eq(33.25))
    end

    it "leaves rows it was not given alone" do
      untouched = create(:lexeme, kind: :word, text: "安靜", score: 7.0)
      target = create(:lexeme, kind: :word, text: "吵鬧", score: 0.0)

      described_class.patch(target: "lexemes", columns: {"score" => "float8"}, rows: [[target.id, 1.0]])

      expect(untouched.reload.score).to(eq(7.0))
    end

    it "merges json instead of replacing it when told to" do
      lexeme = create(:lexeme, kind: :word, text: "字典", data: {"keep" => "yes", "difficulty" => 1})

      described_class.patch(
        target: "lexemes",
        columns: {"patch" => "jsonb"},
        rows: [[lexeme.id, {"difficulty" => 900}]],
        set: "data = lexemes.data || bulk_patch.patch"
      )

      expect(lexeme.reload.data).to(eq({"keep" => "yes", "difficulty" => 900}))
    end

    it "survives text that would otherwise break the copy stream" do
      lexeme = create(:lexeme, kind: :word, text: "換行")

      described_class.patch(
        target: "lexemes",
        columns: {"patch" => "jsonb"},
        rows: [[lexeme.id, {"note" => "tab\there\nand a newline\\plus a backslash"}]],
        set: "data = lexemes.data || bulk_patch.patch"
      )

      expect(lexeme.reload.data["note"]).to(eq("tab\there\nand a newline\\plus a backslash"))
    end

    it "writes nothing and asks the database nothing when there are no rows" do
      expect(described_class.patch(target: "lexemes", columns: {"score" => "float8"}, rows: [])).to(eq(0))
    end

    it "rewrites nothing when the value is already what it would write" do
      lexeme = create(:lexeme, kind: :word, text: "重複", score: 4.0)

      touched = described_class.patch(
        target: "lexemes",
        columns: {"score" => "float8"},
        rows: [[lexeme.id, 4.0]]
      )

      expect(touched).to(eq(0))
    end

    it "counts only the rows that differ when a batch mixes both" do
      same = create(:lexeme, kind: :word, text: "不動", score: 4.0)
      moved = create(:lexeme, kind: :word, text: "有變", score: 4.0)

      touched = described_class.patch(
        target: "lexemes",
        columns: {"score" => "float8"},
        rows: [[same.id, 4.0], [moved.id, 9.5]]
      )

      expect(touched).to(eq(1))
      expect(moved.reload.score).to(eq(9.5))
      expect(same.reload.score).to(eq(4.0))
    end

    it "treats a null on one side as a difference and on both sides as none" do
      filling = create(:lexeme, kind: :word, text: "填空", score: nil)
      empty = create(:lexeme, kind: :word, text: "皆空", score: nil)

      expect(
        described_class.patch(target: "lexemes", columns: {"score" => "float8"}, rows: [[filling.id, 1.0]])
      )
        .to(eq(1))
      expect(
        described_class.patch(target: "lexemes", columns: {"score" => "float8"}, rows: [[empty.id, nil]])
      )
        .to(eq(0))
    end

    it "compares every column before deciding a row is unchanged" do
      lexeme = create(:lexeme, kind: :word, text: "兩欄", score: 4.0, audio_url: "https://example.test/a.mp3")

      touched = described_class.patch(
        target: "lexemes",
        columns: {"score" => "float8", "audio_url" => "varchar"},
        rows: [[lexeme.id, 4.0, "https://example.test/b.mp3"]]
      )

      expect(touched).to(eq(1))
      expect(lexeme.reload.audio_url).to(eq("https://example.test/b.mp3"))
    end

    it "still writes unconditionally when the caller supplies the assignment" do
      lexeme = create(:lexeme, kind: :word, text: "自訂", data: {"difficulty" => 5})

      touched = described_class.patch(
        target: "lexemes",
        columns: {"patch" => "jsonb"},
        rows: [[lexeme.id, {"difficulty" => 5}]],
        set: "data = lexemes.data || bulk_patch.patch"
      )

      expect(touched).to(eq(1))
    end

    it "leaves no scratch table behind" do
      lexeme = create(:lexeme, kind: :word, text: "清理")

      described_class.patch(target: "lexemes", columns: {"score" => "float8"}, rows: [[lexeme.id, 1.0]])

      expect(ActiveRecord::Base.connection.table_exists?("bulk_patch")).to(be(false))
    end
  end

  describe ".upsert" do
    let(:lexeme) { create(:lexeme, kind: :sentence, text: "這是一個句子。", content_sources: [source]) }
    let(:source) do
      ContentSource.create!(slug: "probe", name: "Probe", license_commercial: true, attribution: "probe")
    end

    def upsert(difficulty)
      described_class.upsert(
        target: "sentence_profiles",
        key: "lexeme_id",
        conflict: "lexeme_id",
        columns: {"difficulty" => "integer", "created_at" => "timestamp", "updated_at" => "timestamp"},
        rows: [[lexeme.id, difficulty, Time.current, Time.current]]
      )
    end

    it "inserts a row that is not there yet" do
      upsert(10)

      expect(SentenceProfile.find_by(lexeme_id: lexeme.id).difficulty).to(eq(10))
    end

    it "updates the row on a second pass instead of duplicating it" do
      upsert(10)
      upsert(20)

      expect(SentenceProfile.where(lexeme_id: lexeme.id).count).to(eq(1))
      expect(SentenceProfile.find_by(lexeme_id: lexeme.id).difficulty).to(eq(20))
    end
  end
end
