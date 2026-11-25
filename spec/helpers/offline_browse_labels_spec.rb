# frozen_string_literal: true

require "rails_helper"

RSpec.describe OfflineHelper do
  it "tells the offline list to show only Japanese for sentences on Japanese pages" do
    I18n.with_locale(:ja) { expect(helper.offline_browse_labels[:ownSentencesOnly]).to(be(true)) }
    I18n.with_locale(:en) { expect(helper.offline_browse_labels[:ownSentencesOnly]).to(be(false)) }
  end
end
