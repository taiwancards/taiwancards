# frozen_string_literal: true

module MemoizedInstance
  def instance = @instance ||= new

  def reset! = @instance = nil
end
