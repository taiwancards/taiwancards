# frozen_string_literal: true

class ScanJob < ApplicationJob
  self.queue_adapter = ActiveJob::QueueAdapters::AsyncAdapter.new(
    min_threads: 0,
    max_threads: Scans::Settings.concurrency,
    max_queue: Scans::Settings.concurrency,
    fallback_policy: :abort
  )
  self.log_arguments = false

  class_attribute :recognizer, default: -> { Scans::Recognizer.new }

  def perform(scan_id, images)
    scan = Scan.find_by(id: scan_id)
    return if scan.nil? || !scan.claim!

    reader = recognizer.call
    reading = reader.call(images)
    text, changed = Huayu::SimpToTrad.convert(Scans::TextFilter.call(reading.lines))
    scan.finish!(text:, legibility: reading.legibility, changed:, usage: reading.usage)
    Scans::Credentials.succeeded(reader.key)
  rescue Scans::Recognizer::Failure => failure
    scan&.fail!(failure.code, usage: failure.usage)
    Scans::Incidents.report(failure, reader&.key)
  rescue StandardError => error
    Rails.logger.error("scan #{scan_id} failed: #{error.class.name}")
    scan&.fail!("unavailable")
  end
end
