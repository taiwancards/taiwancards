# frozen_string_literal: true

module QueryCounter
  IGNORED = /\A(TRANSACTION|SCHEMA)\z/
  CACHEABLE = /\A\s*SELECT/i

  Report = Data.define(:statements) do
    def count = statements.length

    def repeated
      statements
        .map { |sql| sql.gsub(/\$\d+|\b\d+\b/, "?").gsub(/IN \([^)]*\)/i, "IN (?)").squish }
        .tally
        .select { |_, hits| hits > 1 }
    end

    def to_s = statements.join("\n")
  end

  def count_queries
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name].to_s.match?(IGNORED) || payload[:cached]

      statements << payload[:sql]
    end

    yield
    Report.new(statements:)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end

RSpec.configure { |config| config.include(QueryCounter) }

RSpec::Matchers.define(:issue_at_most) do |limit|
  match do |report|
    @report = report
    report.count <= limit
  end

  failure_message do
    worst = @report.repeated.sort_by { |_, hits| -hits }.first(5)
    <<~TEXT
      expected at most #{limit} queries, got #{@report.count}
      most repeated:
      #{worst.map { |sql, hits| "  #{hits}x  #{sql.truncate(160)}" }.join("\n")}
    TEXT
  end
end

RSpec::Matchers.define(:repeat_no_query_more_than) do |limit|
  match do |report|
    @over = report.repeated.select { |_, hits| hits > limit }
    @over.empty?
  end

  failure_message do
    <<~TEXT
      expected no query shape to repeat more than #{limit} times
      #{@over.sort_by { |_, hits| -hits }.map { |sql, hits| "  #{hits}x  #{sql.truncate(160)}" }.join("\n")}
    TEXT
  end
end
