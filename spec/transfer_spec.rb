# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "bin/rebuild-data-render.sh" do
  let(:script) { Rails.root.join("bin/rebuild-data-render.sh").read }

  def members(stream)
    names = []
    offset = 0
    while offset + 512 <= stream.bytesize
      header = stream.byteslice(offset, 512)
      name = header[0, 100].delete("\0")
      break if name.empty?

      size = header[124, 12].delete("\0 ").to_i(8)
      names << name
      offset += 512 + ((size + 511) / 512 * 512)
    end

    names
  end

  describe "the tar stream" do
    let(:fixture) { Rails.root.join("tmp/transfer_spec") }

    before do
      fixture.rmtree if fixture.exist?
      fixture.mkpath
      fixture.join("data.json").write("{}")
      system("xattr", "-w", "com.apple.provenance", "probe", fixture.join("data.json").to_s)
    end

    after { fixture.rmtree if fixture.exist? }

    def stream(env)
      out, = Open3.capture2(env, "tar", "-cf", "-", "-C", fixture.to_s, "data.json")
      out
    end

    it "carries macOS metadata as extra files unless it is told not to" do
      unless system(
          "xattr",
          "-p",
          "com.apple.provenance",
          fixture.join("data.json").to_s,
          out: File::NULL,
          err: File::NULL
        )
        skip("no xattr support here")
      end

      expect(members(stream({}))).to(include("._data.json"))
    end

    it "carries nothing that lands as an extra file once it is" do
      names = members(stream({"COPYFILE_DISABLE" => "1"}))

      expect(names).to(include("data.json"))
      expect(names.grep(/(\A|\/)\._/)).to(be_empty)
    end
  end

  it "never lets macOS metadata onto the disk in the first place" do
    expect(script).to(include("--exclude '._*'"))
  end

  it "refuses to finish if metadata files reach the disk anyway" do
    expect(script).to(match(/name '\._\*'.*\n.*die/))
  end

  it "sends only what changed and drops what is gone" do
    expect(script).to(match(/^\s*STATS=\$\(rsync /))
    expect(script).to(include("PRUNE=(--delete)"))
  end

  it "leaves the disk alone unless wiping is asked for by name" do
    expect(script).to(match(/if \[ -n "\$\{WIPE:-\}" \]; then/))
    expect(script.scan(/rm -rf/).length).to(eq(1))
  end

  it "keeps ssh away from the loop it is iterating" do
    expect(script).to(match(/^remote\(\) \{ ssh -n /))
    expect(script).to(include("<&3"))
    expect(script).to(include("done 3<<<"))
  end
end
