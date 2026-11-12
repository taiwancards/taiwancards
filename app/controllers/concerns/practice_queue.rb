# frozen_string_literal: true

module PracticeQueue
  extend ActiveSupport::Concern

  LEGACY_KEY = /\A(?:pron|writing)_(?:queue|position)(?:_\d+)?\z/

  private

  def practice_queue(slot, deck:)
    drop_legacy_queues
    stored = practice_slot(slot, deck)
    queue = Study::Run.unpack(stored["ids"])
    position = stored["pos"].to_i
    position += 1 if params[:advance].present?

    if queue.empty? || position >= queue.size
      queue = yield
      position = 0
    end

    session[slot] = {"deck" => deck, "ids" => Study::Run.pack(queue), "pos" => position}.compact
    [queue, position]
  end

  def move_practice_position(slot, position)
    session[slot] = session[slot].merge("pos" => position)
  end

  def practice_slot(slot, deck)
    stored = session[slot]
    stored.is_a?(Hash) && stored["deck"] == deck ? stored : {}
  end

  def drop_legacy_queues
    session.keys.grep(LEGACY_KEY).each { |key| session.delete(key) }
  end
end
