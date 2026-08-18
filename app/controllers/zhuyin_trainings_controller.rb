# frozen_string_literal: true

class ZhuyinTrainingsController < ApplicationController
  allow_unauthenticated_access
  SIZE = 10

  def show
    @group = params[:group].to_s.presence_in(Huayu::ZhuyinTrainer::GROUPS.keys)
    @scope = params[:block].to_s.presence_in(Huayu::ZhuyinTrainer::KEYS)
    @set = params[:set].to_s.presence_in(Huayu::ZhuyinTrainer::SETS.keys)
    trainer = build_trainer(group: @group, block: @scope, set: @set)
    @blocks = trainer.blocks
    @block = trainer.current_block
    @progress = trainer.progress
    @complete = trainer.complete?
    @items = trainer.items(count: SIZE)
  end

  def update
    trainer = build_trainer
    Array(params[:results]).each do |result|
      symbol = result[:symbol].to_s
      next unless Huayu::ZhuyinTrainer::ALL.include?(symbol)

      trainer.record(
        symbol,
        correct: ActiveModel::Type::Boolean.new.cast(result[:correct]),
        elapsed_ms: result[:elapsed_ms]
      )
    end

    current_user&.update_zhuyin_mastery!(trainer.mastery)
    current_user&.record_practice_run!(:zhuyin_trainer)
    current_user&.record_practice_run!(:drill)
    current_user&.mark_path_step!("zhuyin") if trainer.complete?

    render(json: trainer.progress)
  end

  private

  def build_trainer(group: nil, block: nil, set: nil)
    Huayu::ZhuyinTrainer.new(current_user&.zhuyin_mastery || {}, group:, block:, set:)
  end
end
