# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Festivals and the lunar calendar" do
  it "lists the festivals for the current year" do
    sign_in(create(:user))

    get(calendar_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("春節", "端午節", "中秋節", "冬至"))
  end

  it "computes festival dates for a requested year" do
    sign_in(create(:user))

    get(calendar_path(year: 2026))

    expect(response.body).to(include("2026"))
    expect(response.body).to(include(I18n.t("calendar.day_off")))
  end

  it "explains the lunar day numbering and the leap month" do
    sign_in(create(:user))

    get(calendar_path)

    expect(response.body).to(include("初五", "閏月"))
  end

  it "renders both converters" do
    sign_in(create(:user))

    get(calendar_path)

    expect(response.body).to(include("data-controller=\"minguo\""))
    expect(response.body).to(include("data-controller=\"lunar-converter\""))
    expect(response.body).to(include("data-lunar-converter-table-value"))
  end

  it "offers quick add for festival words already in the dictionary" do
    word = create(:lexeme, kind: :word, text: "月餅", meanings: {"en" => "mooncake"})
    sign_in(create(:user))

    get(calendar_path)

    expect(response.body).to(include(quick_add_path))
    expect(response.body).to(include(dict_entry_path(word.text)))
  end

  it "renders the page and its festival texts in Russian" do
    sign_in(create(:user, locale: "ru"))

    get(calendar_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("calendar.title", locale: :ru)))
    expect(response.body).to(include(Huayu::Holidays.all.first.summary_ru))
  end

  it "translates every festival and word into both locales" do
    en = Huayu::Holidays.all.map { |entry| entry.summary(:en) }
    ru = Huayu::Holidays.all.map { |entry| entry.summary(:ru) }

    expect(en).to(all(be_present))
    expect(ru).to(all(be_present))
    expect(en).not_to(eq(ru))
    expect(I18n.t("calendar.title", locale: :ru)).not_to(eq(I18n.t("calendar.title", locale: :en)))
  end
end

RSpec.describe Huayu::LunarCalendar do
  it "converts lunar dates to Gregorian against known Taiwan festival dates" do
    expect(described_class.to_gregorian(2026, 1, 1)).to(eq(Date.new(2026, 2, 17)))
    expect(described_class.to_gregorian(2026, 5, 5)).to(eq(Date.new(2026, 6, 19)))
    expect(described_class.to_gregorian(2026, 8, 15)).to(eq(Date.new(2026, 9, 25)))
    expect(described_class.to_gregorian(2025, 1, 1)).to(eq(Date.new(2025, 1, 29)))
    expect(described_class.to_gregorian(2024, 1, 1)).to(eq(Date.new(2024, 2, 10)))
  end

  it "handles leap months as a distinct month with the same number" do
    expect(described_class.years[2025].leap_month).to(eq(6))
    expect(described_class.to_gregorian(2025, 6, 1)).to(eq(Date.new(2025, 6, 25)))
    expect(described_class.to_gregorian(2025, 6, 1, leap: true)).to(eq(Date.new(2025, 7, 25)))
  end

  it "round-trips every day it covers" do
    date = described_class.min_date
    until date > described_class.max_date
      lunar = described_class.to_lunar(date)
      back = described_class.to_gregorian(lunar[:year], lunar[:month], lunar[:day], leap: lunar[:leap])
      expect(back).to(eq(date))
      date += 97
    end
  end

  it "names lunar days the way Taiwanese calendars do" do
    expect(described_class.day_label(1)).to(eq("初一"))
    expect(described_class.day_label(5)).to(eq("初五"))
    expect(described_class.day_label(10)).to(eq("初十"))
    expect(described_class.day_label(21)).to(eq("廿一"))
    expect(described_class.day_label(30)).to(eq("三十"))
    expect(described_class.month_label(1)).to(eq("正月"))
    expect(described_class.month_label(6, leap: true)).to(eq("閏六月"))
  end

  it "covers 1950 through 2050 with sane month lengths" do
    expect(described_class.years.keys.minmax).to(eq([1950, 2050]))
    described_class.years.each_value do |year|
      expect(year.month_lengths.uniq - [29, 30]).to(be_empty)
      expect(year.months.size).to(eq(year.leap_month.positive? ? 13 : 12))
    end
  end
end

RSpec.describe Huayu::Holidays do
  it "gives every festival a year-independent rule and words in both languages" do
    expect(described_class.all.size).to(eq(12))

    described_class.all.each do |entry|
      expect(entry.rule["type"]).to(be_in(%w[lunar gregorian solar_term]))
      expect(entry.words.size).to(be_between(5, 10))
      expect(entry.summary_en).to(be_present)
      expect(entry.summary_ru).to(be_present)
      entry.words.each do |word|
        expect(word.gloss_en).to(be_present)
        expect(word.gloss_ru).to(be_present)
      end
    end
  end

  it "places the solar-term festivals on their solar-term dates" do
    rows = described_class.for_year(2026).to_h { |row| [row[:entry].key, row[:date]] }

    expect(rows["qingming"]).to(eq(Date.new(2026, 4, 5)))
    expect(rows["dongzhi"]).to(eq(Date.new(2026, 12, 22)))
    expect(rows["double_ten"]).to(eq(Date.new(2026, 10, 10)))
  end
end
