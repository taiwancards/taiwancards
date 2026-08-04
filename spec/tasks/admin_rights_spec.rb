# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "deploy:sync admin_rights" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("deploy:sync") }

  def settle = ALWAYS_STEPS.fetch("admin_rights").call

  it "grants the flag to the one Google account that should carry it" do
    owner = create(:user, :admin)
    owner.update_columns(admin: false, restricted_content: false)

    expect(settle).to(eq(:ran))

    expect(owner.reload.admin).to(be(true))
    expect(owner.restricted_content).to(be(true))
  end

  it "takes it from anybody else who still has it" do
    other = create(:user)
    other.update_columns(admin: true)

    expect(settle).to(eq(:ran))

    expect(other.reload.admin).to(be(false))
  end

  it "settles after one pass" do
    create(:user, :admin).update_columns(admin: false)
    create(:user).update_columns(admin: true)
    settle

    expect(settle).to(eq(:skipped))
  end

  it "does nothing at all when the flags already match the rule" do
    create(:user, :admin)
    create(:user)

    expect(settle).to(eq(:skipped))
  end
end
