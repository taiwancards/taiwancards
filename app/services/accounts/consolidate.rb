# frozen_string_literal: true

module Accounts
  class Consolidate
    FIRST_ID = 1

    Result = Data.define(:deleted, :kept, :renumbered, :attached, :next_id)

    def initialize(email = User.owner_google_email)
      @email = email
    end

    def call
      keeper = User.find_by!(google_email: @email)

      ActiveRecord::Base.transaction do
        deleted = User.where.not(id: keeper.id).destroy_all.size
        attached = rows_for(keeper)
        moved = attached.zero? && renumber(keeper)
        restart if moved || keeper.id == FIRST_ID

        Result.new(deleted:, kept: @email, renumbered: moved, attached:, next_id: User.maximum(:id).to_i + 1)
      end
    end

    private

    def owned_tables
      @owned_tables ||= connection.tables.select do |table|
        connection.columns(table).any? { |column| column.name == "user_id" }
      end
    end

    def rows_for(keeper)
      owned_tables.sum do |table|
        connection
          .select_value(
            ActiveRecord::Base.sanitize_sql_array(
              ["SELECT count(*) FROM #{connection.quote_table_name(table)} WHERE user_id = ?", keeper.id]
            )
          )
          .to_i
      end
    end

    def renumber(keeper)
      return false if keeper.id == FIRST_ID

      connection.update(
        ActiveRecord::Base.sanitize_sql_array(["UPDATE users SET id = ? WHERE id = ?", FIRST_ID, keeper.id])
      )
      true
    end

    def restart
      connection.execute(
        ActiveRecord::Base.sanitize_sql_array(
          ["SELECT setval(pg_get_serial_sequence('users', 'id'), ?, true)", FIRST_ID]
        )
      )
    end

    def connection = ActiveRecord::Base.connection
  end
end
