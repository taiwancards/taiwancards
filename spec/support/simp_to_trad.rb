# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    allow(AppData).to(receive(:path).and_call_original)
    allow(AppData).to(
      receive(:path)
        .with(Huayu::SimpToTrad::PATH)
        .and_return(Rails.root.join("spec/fixtures/files/simp_to_trad.txt"))
    )
    Huayu::SimpToTrad.reset!
  end

  config.after { Huayu::SimpToTrad.reset! }
end
