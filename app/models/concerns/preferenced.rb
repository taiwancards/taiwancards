# frozen_string_literal: true

module Preferenced
  extend ActiveSupport::Concern

  class_methods do
    def preference(name, key: name.to_s, one_of: nil, within: nil, default: nil, allow_nil: false)
      define_method(name) do
        cast(prefs[key], one_of:, within:, default:, allow_nil:)
      end

      define_method(:"#{name}=") do |value|
        write_prefs(key => cast(value, one_of:, within:, default:, allow_nil:))
      end
    end
  end

  def write_prefs(values)
    self.prefs = prefs.merge(values.transform_keys(&:to_s))
  end

  private

  def cast(value, one_of:, within:, default:, allow_nil:)
    return clamped(value, within) if within
    return value.nil? ? default : value if one_of.nil?

    allowed = one_of.is_a?(Proc) ? instance_exec(&one_of) : one_of
    text = value.to_s
    return text if allowed.include?(text)

    allow_nil ? nil : (default || allowed.first)
  end

  def clamped(value, within)
    range = within.is_a?(Proc) ? instance_exec(&within) : within
    value.to_i.clamp(range.begin, range.end)
  end
end
