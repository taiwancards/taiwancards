# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scans::Upload do
  def uploaded(bytes, type: "image/jpeg")
    file = Tempfile.new(["scan", ".jpg"], binmode: true)
    file.write(bytes)
    file.rewind
    ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: "scan.jpg", type:)
  end

  def fixture(name) = uploaded(file_fixture("scans/#{name}").binread)

  it "accepts a real JPEG and measures it from its own header" do
    upload = described_class.new(fixture("page.jpg"))

    expect(upload).to(be_valid)
    expect([upload.width, upload.height]).to(eq([800, 600]))
    expect(Base64.strict_decode64(upload.base64)).to(eq(file_fixture("scans/page.jpg").binread.b))
  end

  it "ignores the type the browser claims and reads the magic bytes" do
    expect(described_class.new(fixture("disguised.jpg")).error).to(eq("not_image"))
    expect(described_class.new(uploaded("<html>not a photo</html>", type: "image/jpeg")).error).to(eq("not_image"))
  end

  it "refuses bytes that start like a JPEG but have no image in them" do
    expect(described_class.new(uploaded("\xFF\xD8\xFF".b + ("\x00".b * 500))).error).to(eq("not_image"))
  end

  it "refuses pictures beyond the pixel limits" do
    expect(described_class.new(fixture("wide.jpg")).error).to(eq("too_large"))
    expect(described_class.new(fixture("tiny.jpg")).error).to(eq("too_small"))
  end

  it "refuses files over the byte limit without reading them" do
    big = uploaded("\xFF\xD8\xFF".b + ("\x00".b * described_class::MAX_BYTES))

    expect(described_class.new(big).error).to(eq("too_large"))
  end

  it "refuses anything that is not one uploaded file" do
    expect(described_class.new(nil).error).to(eq("missing"))
    expect(described_class.new("data:image/jpeg;base64,AAAA").error).to(eq("missing"))
    expect(described_class.new([fixture("page.jpg"), fixture("page.jpg")]).error).to(eq("missing"))
  end
end
