# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Content licensing" do
  def source!(slug, commercial:, statistics_only: false, enabled: true)
    ContentSource.create!(
      slug: slug,
      name: slug.titleize,
      license_commercial: commercial,
      statistics_only: statistics_only,
      register: :publicistic,
      enabled: enabled,
      enabled_for_admins: enabled,
      attribution: "#{slug}."
    )
  end

  def sentence!(text, source)
    lexeme = Lexeme.new(kind: :sentence, text: text, meanings: {})
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  let(:commercial) { source!("wikivoyage", commercial: true) }
  let(:non_commercial) { source!("ted_talks", commercial: false) }
  let(:statistics_only) { source!("moj_law", commercial: true, statistics_only: true) }

  it "hides text whose licence forbids commercial use, even when the source is enabled" do
    open = sentence!("開放的句子。", commercial)
    closed = sentence!("受限的句子。", non_commercial)

    expect(Lexeme.visible.where(kind: :sentence).ids).to(eq([open.id]))
    expect(Lexeme.visible.where(kind: :sentence).ids).not_to(include(closed.id))
  end

  it "hides text from sources admitted for measurement only" do
    counted = sentence!("只做統計的句子。", statistics_only)

    expect(Lexeme.visible.where(kind: :sentence).ids).not_to(include(counted.id))
  end

  it "gives an administrator no licence an anonymous reader lacks" do
    sentence!("開放的句子。", commercial)
    sentence!("受限的句子。", non_commercial)
    admin = build(:user, :admin)

    expect(ContentSource.visible_to(admin).pluck(:slug)).to(eq(ContentSource.visible_to(nil).pluck(:slug)))
  end

  it "admits nothing that is neither commercially licensed nor marked for measurement" do
    source!("wikivoyage", commercial: true)
    source!("ted_talks", commercial: false)

    expect(ContentSource.publishable.ids | ContentSource.measurement_only.ids).to(match_array(ContentSource.ids))
  end
end
