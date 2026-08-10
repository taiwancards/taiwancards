# frozen_string_literal: true

module MaintenanceWindow
  STATEMENT_TIMEOUT = "15min"
  LOCK_TIMEOUT = "1min"

  def self.open!(connection = ActiveRecord::Base.connection)
    connection.execute("SET statement_timeout = #{connection.quote(STATEMENT_TIMEOUT)}")
    connection.execute("SET lock_timeout = #{connection.quote(LOCK_TIMEOUT)}")
    self
  end
end
