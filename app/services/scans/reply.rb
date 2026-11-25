# frozen_string_literal: true

module Scans
  class Reply
    GAP = "□"
    NOTES = {"partly_blurred" => "blurred", "unreadable" => "unreadable", "none" => "no_text"}.freeze

    def initialize(scan)
      @scan = scan
    end

    def as_json(*)
      return {state: "pending"} if @scan.pending?
      return failed if @scan.failed?

      done
    end

    private

    def failed
      {state: "failed", message: I18n.t("scan.failures.#{@scan.failure}"), **Panel.remaining(@scan.user)}
    end

    def done
      text = @scan.text.to_s
      note = text.empty? ? notice_for_empty : (text.include?(GAP) ? "gaps" : NOTES[@scan.legibility])
      {
        state: "done",
        text:,
        changed: (I18n.t("scan.notes.changed", chars: changed_chars) if @scan.changed_chars.any?),
        note: (I18n.t("scan.notes.#{note}") if note),
        **Panel.remaining(@scan.user)
      }
    end

    def changed_chars = @scan.changed_chars.first(12).join(" ")

    def notice_for_empty = @scan.legibility == "unreadable" ? "unreadable" : "no_text"
  end
end
