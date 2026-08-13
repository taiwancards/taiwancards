# frozen_string_literal: true

require "zip"
require "tmpdir"
require "open-uri"

module Fonts
  class KaiBuilder
    MEMBER = "TW-Kai-98_1.ttf"
    RANGES = "U+0020-007E,U+00A0-00FF,U+2000-206F,U+3000-303F,U+FF00-FFEF," \
      "U+3105-312F,U+31A0-31BF,U+02C7,U+02CA,U+02CB,U+02D9"
    UI_GLYPHS = "U+81FA"
    CORE_SIZE = 300
    SLICE_SIZE = 1200
    CORE_FILE = "tw-kai-core.woff2"
    SLICE_FILE = "tw-kai-%02d.woff2"
    FACES_FILE = Rails.root.join("app/assets/stylesheets/kai_faces.css")

    def initialize(workspace)
      @workspace = workspace
    end

    def prepare_python
      venv = @workspace.join("venv")
      return nil unless system("python3", "-m", "venv", venv.to_s, out: File::NULL, err: File::NULL)

      pip = venv.join("bin/pip")
      return nil unless system(pip.to_s, "install", "-q", "fonttools", "brotli", out: File::NULL, err: File::NULL)

      venv.join("bin/pyftsubset")
    end

    def call(python:, directory:)
      archive = @workspace.join("kai.zip")
      source = Sources.url("CNS11643_KAI_FONT_URL")
      puts("fonts:kai downloading #{source}")
      archive.binwrite(URI.parse(source).open("User-Agent" => FontAssets::USER_AGENT, &:read))

      ttf = extract(archive)
      raise "#{MEMBER} missing from the archive" if ttf.nil?

      core, slices = plan
      puts("fonts:kai #{core.size} codepoints in the core face, #{slices.sum(&:size)} in #{slices.size} slices")

      FileUtils.mkdir_p(directory)
      FileUtils.rm_f(directory.glob("tw-kai-*.woff2"))
      raise "pyftsubset failed for the core face" unless subset(python, ttf, core, directory.join(CORE_FILE))

      slices.each_with_index do |points, index|
        target = directory.join(format(SLICE_FILE, index + 1))
        raise "pyftsubset failed for #{target.basename}" unless subset(python, ttf, points, target)
      end

      write_faces(core, slices)
      report(directory)
    end

    private

    def extract(archive)
      Zip::File.open(archive) do |zip|
        entry = zip.find { |candidate| File.basename(candidate.name) == MEMBER }
        next nil if entry.nil?

        destination = @workspace.join(MEMBER)
        destination.binwrite(entry.get_input_stream(&:read))
        destination
      end
    end

    def plan
      pinned = expand("#{RANGES},#{UI_GLYPHS}")
      characters = ordered_characters
      core = (pinned + characters.first(CORE_SIZE).map(&:ord)).uniq.sort
      rest = characters.drop(CORE_SIZE).map(&:ord).uniq - core
      [core, rest.each_slice(SLICE_SIZE).map(&:sort)]
    end

    def ordered_characters
      ranks = rank_map
      rendered_text
        .flat_map(&:chars)
        .uniq
        .select { |char| han?(char) }
        .sort_by { |char| ranks.fetch(char, [Float::INFINITY, Float::INFINITY]) + [char.ord] }
    end

    def rendered_text
      Lexeme.pluck(:text) + Lexeme.pluck(:data).map(&:to_s)
    end

    def han?(char)
      point = char.ord

      point.between?(0x2E80, 0x2EF3) ||
        point.between?(0x2F00, 0x2FDF) ||
        point.between?(0x2FF0, 0x2FFB) ||
        point.between?(0x3400, 0x4DBF) ||
        point.between?(0x4E00, 0x9FFF) ||
        point.between?(0xF900, 0xFAFF)
    end

    def rank_map
      Lexeme
        .pluck(:text, Arel.sql("(data->>'freq_rank')::int"), Arel.sql("(data->>'moe_index')::int"))
        .each_with_object({}) do |(text, frequency, dictionary), map|
          next unless text.chars.size == 1

          map[text] = [frequency || Float::INFINITY, dictionary || Float::INFINITY]
        end
    end

    def expand(ranges)
      ranges.split(",").flat_map { |token|
        bounds = token.strip.delete_prefix("U+").split("-").map { |value| value.to_i(16) }
        bounds.size == 1 ? bounds : (bounds.first..bounds.last).to_a
      }
    end

    def subset(python, ttf, points, target)
      system(
        python.to_s,
        ttf.to_s,
        "--unicodes=#{points.map { |point| format("U+%04X", point) }.join(",")}",
        "--flavor=woff2",
        "--layout-features=*",
        "--output-file=#{target}",
        out: File::NULL,
        err: File::NULL
      )
    end

    def write_faces(core, slices)
      faces = [face(CORE_FILE, core)]
      slices.each_with_index { |points, index| faces << face(format(SLICE_FILE, index + 1), points) }
      FACES_FILE.write(faces.join("\n"))
    end

    def face(file, points)
      <<~CSS
        @font-face {
          font-family: 'TW Kai';
          font-style: normal;
          font-weight: 400;
          font-display: swap;
          src: url("#{FontAssets::MOUNT}/#{file}") format('woff2');
          unicode-range: #{unicode_range(points)};
        }
      CSS
    end

    def unicode_range(points)
      points
        .slice_when { |previous, current| current != previous + 1 }
        .map { |run|
          run.size == 1 ? format("U+%04X", run.first) : format("U+%04X-%04X", run.first, run.last)
        }
        .join(", ")
    end

    def report(directory)
      core = directory.join(CORE_FILE).size
      slices = directory.glob("tw-kai-[0-9]*.woff2").sum(&:size)
      puts("fonts:kai core face #{(core / 1024.0).round} KB, slices #{(slices / 1024.0 / 1024).round(2)} MB in total")
      puts("fonts:kai faces written to #{FACES_FILE.relative_path_from(Rails.root)}")
    end
  end
end
