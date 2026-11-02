# frozen_string_literal: true

module Huayu
  class NoticeImporter < CuratedSentenceImporter
    SOURCE = "community_notices"
    MARKER = "notice"

    private

    def wanted
      @wanted ||= TaiwanNotices.all.each_with_object({}) do |notice, all|
        notice.items.each do |item|
          all[item.zh] = item.names.slice(*Locales::ALL).compact_blank
        end
      end
    end
  end
end
