# frozen_string_literal: true

module Deploy
  class DictionaryPush
    def initialize(url, dump, kinds, io: $stdout)
      @url = url
      @dump = dump
      @kinds = kinds
      @io = io
    end

    def call
      status = nil
      Open3.popen2e("psql", @url, "-v", "ON_ERROR_STOP=1", "-q", "-f", "-") do |stdin, out, wait|
        stdin.write(script)
        stdin.close
        out.each_line { |line| @io.print(line) }
        status = wait.value
      end

      raise "psql failed (exit #{status.exitstatus})" unless status.success?
    end

    private

    def numbers
      @kinds.map { |kind| Lexeme.kinds.fetch(kind) }.join(",")
    end

    def script
      <<~SQL
        \\set ON_ERROR_STOP on

        -- temp table lives in temp_buffers; the 8MB default cannot hold the dictionary,
        -- and the value is only settable before the first temp table is touched.
        set temp_buffers = '128MB';

        begin;

        create temp table incoming (
          kind integer not null,
          text varchar not null,
          readings jsonb not null,
          meanings jsonb not null,
          data jsonb not null,
          sources jsonb not null,
          score double precision,
          search_text text,
          restricted boolean not null
        ) on commit drop;

        \\copy incoming from '#{@dump}' with (format text, null '\\N')

        select count(*) as "rows_received" from incoming;
        insert into lexemes
          (kind, text, readings, meanings, data, sources, score, search_text, restricted, created_at, updated_at)
        select incoming.kind, incoming.text, incoming.readings, incoming.meanings,
               incoming.data, incoming.sources, incoming.score, incoming.search_text, incoming.restricted,
               now(), now()
        from incoming
        on conflict (kind, text) do update set
          readings = excluded.readings,
          meanings = excluded.meanings,
          data = excluded.data,
          sources = excluded.sources,
          score = excluded.score,
          search_text = excluded.search_text,
          restricted = excluded.restricted,
          updated_at = now()
        where (lexemes.readings, lexemes.meanings, lexemes.data, lexemes.sources,
               lexemes.score, lexemes.search_text, lexemes.restricted)
          is distinct from
              (excluded.readings, excluded.meanings, excluded.data, excluded.sources,
               excluded.score, excluded.search_text, excluded.restricted);

        commit;

        select kind,
               count(*) as "total",
               count(*) filter (where coalesce(trim(meanings->>'en'), '') = '') as "no_en",
               count(*) filter (where coalesce(trim(meanings->>'ru'), '') = '') as "no_ru",
               count(*) filter (where score is null) as "no_score"
        from lexemes
        where kind in (#{numbers})
        group by kind
        order by kind;
      SQL
    end
  end
end
