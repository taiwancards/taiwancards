# frozen_string_literal: true

namespace(:huayu) do
  desc("Give every sentence a UUIDv7 for its public URL (idempotent)")
  task(backfill_public_ids: :environment) do
    scope = Lexeme.where(kind: Lexeme::PUBLIC_ID_KINDS, public_id: nil)
    total = scope.count

    if total.zero?
      puts("every sentence already has a public id")
      next
    end

    puts("to fill: #{total}")
    done = 0

    scope.in_batches(of: 5_000).each do |batch|
      pairs = batch.pluck(:id).sort.map { |id| [id, SecureRandom.uuid_v7] }
      values = pairs.map { |id, uuid| "(#{id}, '#{uuid}'::uuid)" }.join(",")

      Lexeme.connection.exec_update(<<~SQL.squish, "backfill_public_ids")
        UPDATE lexemes SET public_id = incoming.public_id
        FROM (VALUES #{values}) AS incoming(id, public_id)
        WHERE lexemes.id = incoming.id
      SQL

      done += pairs.length
      print("\r  #{done}/#{total}")
    end

    puts("")
    puts("still without an id: #{Lexeme.where(kind: Lexeme::PUBLIC_ID_KINDS, public_id: nil).count}")
  end
end
