# frozen_string_literal: true

namespace(:lang) do
  namespace(:zh_tw) do
    desc("zh-TW: download only freely-licensed open-source files (makemeahanzi, hanzilookup). Skips present files.")
    task(fetch_open: :environment) do
      dir = AppData.path("dictionaries/makemeahanzi")
      FileUtils.mkdir_p(dir)
      {
        "dictionary.txt" => Sources.url("MAKEMEAHANZI_DICTIONARY_URL"),
        "graphics.txt" => Sources.url("MAKEMEAHANZI_GRAPHICS_URL")
      }.each do |name, url|
        file = dir.join(name)
        if file.size?
          puts("makemeahanzi #{name} present, skipping")
        else
          system("curl", "-sL", "-o", file.to_s, url, exception: true)
          puts("makemeahanzi #{name} downloaded (#{file.size / 1024 / 1024} MB)")
        end
      end

      simp = AppData.path("dictionaries/simp_to_trad.txt")
      FileUtils.mkdir_p(simp.dirname)
      if simp.size?
        puts("simplified→traditional map present, skipping")
      else
        system("curl", "-sL", "-o", simp.to_s, Sources.url("OPENCC_ST_URL"), exception: true)
        puts("simplified→traditional map downloaded (#{simp.each_line.count} entries, OpenCC, Apache-2.0)")
      end

      mmah = SharedAssets.directory("json").join("hanzilookup-mmah.json")
      FileUtils.mkdir_p(mmah.dirname)
      if mmah.size?
        puts("hanzilookup data present, skipping")
      else
        system("curl", "-sL", "-o", mmah.to_s, Sources.url("HANZILOOKUP_DATA_URL"), exception: true)
        data = JSON.parse(mmah.read)
        kept = data["chars"].select { |entry| Huayu::Traditional.char?(entry[0]) }
        removed = data["chars"].size - kept.size
        data["chars"] = kept
        mmah.write(JSON.generate(data))
        puts("hanzilookup data downloaded and filtered to Taiwan traditional (removed #{removed} non-Big5 chars)")
      end
    end

    desc("zh-TW: download every external file including scraped Textbook audio (skips files already present)")
    task(fetch: :environment) do
      Rake::Task["lang:zh_tw:fetch_open"].invoke
      Rake::Task["textbook:download_audio"].invoke
    end

    desc("zh-TW: build the whole language from source files — downloads whatever is missing, then imports everything (idempotent). Alias for huayu:build:all")
    task(load: :environment) do
      Rake::Task["huayu:build:all"].invoke
    end
  end
end
