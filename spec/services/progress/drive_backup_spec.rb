# frozen_string_literal: true

require "rails_helper"

RSpec.describe Progress::DriveBackup do
  let!(:lexeme) { create(:lexeme, kind: :word, text: "學校") }
  let(:user) { create(:user) }

  let(:fake_client) do
    Class
      .new do
        def initialize
          @store = {}
        end

        def upload(name:, content:, mime: nil)
          id = "id-#{@store.size}"
          @store[id] = {name:, content:}
          {"id" => id, "name" => name}
        end

        def backups
          @store.keys.reverse.map { |id| {"id" => id, "name" => @store[id][:name]} }
        end

        def download(id)
          @store.fetch(id)[:content]
        end
      end
      .new
  end

  it "round-trips progress through a compressed, timestamped Drive backup" do
    Current.set(user:) do
      memory = Lexemes::Activator.new.activate(lexeme, :recognition)
      Lexemes::ReviewProcessor.new.call(memory, rating: "good")
    end

    name = Progress::DriveBackup.new(user, client: fake_client).save
    expect(name).to(match(/\Ataiwancards-progress-\d{4}-\d{2}-\d{2}-\d{6}\.json\.gz\z/))

    other = create(:user)
    result = Progress::DriveBackup.new(other, client: fake_client).restore
    expect(result[:memories]).to(be_positive)

    restored = other.lexeme_memories.joins(:lexeme).find_by(lexemes: {text: "學校"})
    expect(restored).to(be_present)
  end
end
