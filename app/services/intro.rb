# frozen_string_literal: true

module Intro
  module_function

  def gated?
    ENV.fetch("INTRO_GATE", "on") != "off"
  end

  def bypassed? = !gated?
end
