# frozen_string_literal: true

module Newsletters
  class Stats
    Row = Data.define(:recipients, :sent, :pending, :failed, :clicked, :clicks, :unsubscribed)

    def initialize(newsletters)
      ids = newsletters.map(&:id)
      @rows = ids.empty? ? {} : aggregate(ids)
    end

    def for(newsletter) = @rows.fetch(newsletter.id) { Row.new(0, 0, 0, 0, 0, 0, 0) }

    private

    def aggregate(ids)
      NewsletterDelivery
        .where(newsletter_id: ids)
        .group(:newsletter_id)
        .pluck(
          :newsletter_id,
          Arel.sql("COUNT(*)"),
          Arel.sql("COUNT(sent_at)"),
          Arel.sql("COUNT(*) FILTER (WHERE sent_at IS NULL)"),
          Arel.sql("COUNT(error) FILTER (WHERE sent_at IS NULL)"),
          Arel.sql("COUNT(clicked_at)"),
          Arel.sql("COALESCE(SUM(clicks_count), 0)"),
          Arel.sql("COUNT(unsubscribed_at)")
        )
        .to_h { |id, *counts| [id, Row.new(*counts.map(&:to_i))] }
    end
  end
end
