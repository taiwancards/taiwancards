# frozen_string_literal: true

namespace(:news) do
  desc("Fetch the latest 公視 PTS headlines into the reader (idempotent, personal-use only)")
  task(fetch_pts: :environment) do
    result = News::PtsFetcher.new.call
    if result[:error]
      puts("PTS feed unreachable — nothing imported")
    else
      puts("PTS: #{result[:created]} new item(s)")
    end
  end
end
