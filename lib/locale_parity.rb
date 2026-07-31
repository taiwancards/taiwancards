# frozen_string_literal: true

class LocaleParity
  PLURAL_KEYS = %w[zero one two few many other].to_set
  PAIRS = [%w[en.yml ru.yml], %w[pron.en.yml pron.ru.yml]].freeze

  def initialize(root: Rails.root.join("config/locales"), pairs: PAIRS)
    @root = Pathname(root)
    @pairs = pairs
  end

  def problems
    pairs.flat_map { |left, right| compare(left, right) }
  end

  private

  attr_reader :root, :pairs

  def compare(left_name, right_name)
    left = read(left_name)
    right = read(right_name)

    missing(left, right, right_name) +
      missing(right, left, left_name) +
      (left.keys & right.keys).filter_map { |key| interpolation_gap(key, left, right, left_name, right_name) }
  end

  def missing(from, to, name)
    (from.keys - to.keys).map { |key| "#{key}: missing from #{name}" }
  end

  def interpolation_gap(key, left, right, left_name, right_name)
    here = placeholders(left[key])
    there = placeholders(right[key])
    return if here == there

    "#{key}: #{left_name} takes #{here.to_a.inspect}, #{right_name} takes #{there.to_a.inspect}"
  end

  def read(name)
    leaves(YAML.load_file(root.join(name)).values.first)
  end

  def leaves(node, prefix = [])
    return {prefix.join(".") => node} unless node.is_a?(Hash)
    return {prefix.join(".") => node} if node.keys.map(&:to_s).to_set.subset?(PLURAL_KEYS)

    node.reduce({}) { |all, (key, value)| all.merge(leaves(value, prefix + [key])) }
  end

  def placeholders(value)
    Array(value.is_a?(Hash) ? value.values : value).join(" ").scan(/%\{(\w+)\}/).flatten.to_set
  end
end
