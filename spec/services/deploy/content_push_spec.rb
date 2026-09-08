# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe Deploy::ContentPush do
  SCHEMA = "content_push_spec"
  WORD = 900_001
  SENTENCE = 900_002
  NEW_WORD = 900_003
  USER = 900_001

  def url(schema: nil)
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    base = "postgres://#{config[:host] || "localhost"}:#{config[:port] || 5432}/#{config[:database]}"
    schema ? "#{base}?options=-c%20search_path%3D#{schema},public" : base
  end

  let(:prod) { Deploy::ContentDiff.connect(url).tap { |c| c.exec("SET client_min_messages = warning") } }
  let(:mirror) { Deploy::ContentDiff.connect(url(schema: SCHEMA)) }
  let(:dir) { Dir.mktmpdir }
  let(:push) {
    described_class.new(
      mirror_url: url(schema: SCHEMA),
      prod_url: url,
      io: StringIO.new,
      snapshot: File.join(dir, "snapshot.json")
    )
  }

  before do
    prod.exec("DROP SCHEMA IF EXISTS #{SCHEMA} CASCADE; CREATE SCHEMA #{SCHEMA}")
    (Deploy::ContentTables.names + %w[settings users]).each do |name|
      prod.exec("CREATE TABLE #{SCHEMA}.#{name} (LIKE public.#{name} INCLUDING ALL)")
    end

    prod.exec(
      <<~SQL
        INSERT INTO content_sources (id, name, slug, created_at, updated_at) VALUES (900001, 'Push spec', 'push-spec', now(), now());
        INSERT INTO lexemes (id, kind, text, score, created_at, updated_at) VALUES
          (#{WORD}, 1, 'push-spec-word', 1.5, now(), now()),
          (#{SENTENCE}, 2, 'push-spec-sentence', NULL, now(), now());
        INSERT INTO sentence_profiles (lexeme_id, difficulty, created_at, updated_at) VALUES (#{SENTENCE}, 3, now(), now());
        INSERT INTO sentence_words (sentence_id, lexeme_id, gdex) VALUES (#{SENTENCE}, #{WORD}, 7);
        INSERT INTO settings (data, created_at, updated_at)
          VALUES ('{"study_display": {"front": "prod"}, "sync_fingerprints": {"x": "1"}}', now(), now());
      SQL
    )
  end

  after do
    prod.exec(
      <<~SQL
        DELETE FROM lexeme_memories WHERE user_id = #{USER};
        DELETE FROM users WHERE id = #{USER};
        DELETE FROM sentence_words WHERE lexeme_id >= 900000 OR sentence_id >= 900000;
        DELETE FROM sentence_profiles WHERE lexeme_id >= 900000;
        DELETE FROM lexemes WHERE id >= 900000;
        DELETE FROM content_sources WHERE id >= 900000;
        DELETE FROM settings;
        DROP SCHEMA IF EXISTS #{SCHEMA} CASCADE;
      SQL
    )
    prod.close
    mirror.close
    FileUtils.remove_entry(dir)
  end

  def count(connection, table) = connection.exec("SELECT count(*) FROM #{table}").getvalue(0, 0).to_i

  def settings(connection) = JSON.parse(connection.exec("SELECT data FROM settings ORDER BY id LIMIT 1").getvalue(0, 0))

  def flushed(connection)
    connection.exec("SELECT pg_stat_force_next_flush()")
    connection.exec("SELECT 1")
  end

  it "copies the production content, the settings row and the sequences into the mirror and snapshots it" do
    push.refresh

    expect(count(mirror, "lexemes")).to(eq(2))
    expect(count(mirror, "sentence_words")).to(eq(1))
    expect(settings(mirror)).to(eq(settings(prod)))
    expect(JSON.parse(File.read(File.join(dir, "snapshot.json")))).to(include("digests", "stats", "taken_at"))
    expect(push.plan).to(be_empty)
  end

  it "plans exactly what the mirror changed" do
    push.refresh
    mirror.exec(
      <<~SQL
        UPDATE lexemes SET score = 42 WHERE id = #{WORD};
        INSERT INTO lexemes (id, kind, text, created_at, updated_at) VALUES (#{NEW_WORD}, 1, 'push-spec-new', now(), now());
        DELETE FROM sentence_words WHERE sentence_id = #{SENTENCE};
      SQL
    )

    report = push.plan
    by_name = report.plans.to_h { |plan| [plan.table.name, plan] }

    expect(by_name["lexemes"].updates).to(eq([[WORD]]))
    expect(by_name["lexemes"].inserts).to(eq([[NEW_WORD]]))
    expect(by_name["sentence_words"].deletes).to(eq([[SENTENCE, WORD]]))
    expect(report.cascade).to(be_empty)
  end

  it "pushes the plan, merges the fingerprints and leaves the other production settings alone" do
    push.refresh
    mirror.exec(
      <<~SQL
        UPDATE lexemes SET score = 42 WHERE id = #{WORD};
        INSERT INTO lexemes (id, kind, text, created_at, updated_at) VALUES (#{NEW_WORD}, 1, 'push-spec-new', now(), now());
        DELETE FROM sentence_words WHERE sentence_id = #{SENTENCE};
        UPDATE settings SET data = '{"study_display": {"front": "mirror"}, "sync_fingerprints": {"x": "2"}, "profile_vocabulary": "v2"}';
      SQL
    )

    push.push

    expect(prod.exec("SELECT score FROM lexemes WHERE id = #{WORD}").getvalue(0, 0)).to(eq("42"))
    expect(count(prod, "lexemes")).to(eq(3))
    expect(count(prod, "sentence_words")).to(eq(0))
    expect(settings(prod)).to(
      eq("study_display" => {"front" => "prod"}, "sync_fingerprints" => {"x" => "2"}, "profile_vocabulary" => "v2")
    )
    expect(push.plan).to(be_empty)
  end

  it "refuses when production changed after the snapshot" do
    push.refresh
    prod.exec("UPDATE lexemes SET score = 9 WHERE id = #{WORD}")

    expect { push.plan }.to(raise_error(described_class::Refused, /production changed.*lexemes/))
  end

  it "refuses when the mirror run wrote a table it does not carry" do
    push.refresh
    mirror.exec(
      "INSERT INTO users (id, email, password_digest, created_at, updated_at) VALUES (1, 'stray@example.test', 'x', now(), now())"
    )
    flushed(mirror)

    expect { push.plan }.to(raise_error(described_class::Refused, /wrote to users/))
  end

  it "refuses to drop a lexeme users still study unless told to cascade, then removes their rows too" do
    push.refresh
    prod.exec(
      <<~SQL
        INSERT INTO users (id, email, password_digest, created_at, updated_at) VALUES (#{USER}, 'push-spec@example.test', 'x', now(), now());
        INSERT INTO lexeme_memories (lexeme_id, user_id, created_at, updated_at) VALUES (#{WORD}, #{USER}, now(), now());
      SQL
    )
    mirror.exec("DELETE FROM sentence_words WHERE lexeme_id = #{WORD}; DELETE FROM lexemes WHERE id = #{WORD}")
    flushed(mirror)

    expect { push.plan }.to(raise_error(described_class::Refused, /referenced by lexeme_memories/))

    push.push(cascade: true)

    expect(count(prod, "lexeme_memories")).to(eq(0))
    expect(prod.exec("SELECT count(*) FROM lexemes WHERE id = #{WORD}").getvalue(0, 0)).to(eq("0"))
  end
end
