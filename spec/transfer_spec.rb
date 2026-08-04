# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "bin/distribute" do
  let(:script) { Rails.root.join("bin/distribute").read }

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

  it "builds the templates archive without macOS metadata" do
    expect(script).to(include("COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata"))
  end

  it "compares a digest before sending anything, so an unchanged run moves nothing" do
    expect(script).to(match(/digest="\$\(sha_file "\$src"\)"/))
    expect(script).to(match(/digest="\$\(sha_tree "\$src"\)"/))
    expect(script.scan(/remote_sha "\$dest"/).length).to(eq(2))
  end

  it "stamps what it sends so the next run can recognise it" do
    expect(script.scan(/--metadata "sha256=\$digest"/).length).to(eq(2))
  end

  it "digests an archive from its source tree, never from the tarball it just built" do
    expect(script).to(match(/sha_tree\(\) \{\n\s*find /))
  end
end
