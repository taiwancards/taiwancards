# frozen_string_literal: true

class MetroController < ApplicationController
  allow_unauthenticated_access
  LINES = [
    ["文湖線", "#c48c31"],
    ["淡水信義線", "#d8232a"],
    ["松山新店線", "#128b45"],
    ["中和新蘆線", "#f5a623"],
    ["板南線", "#0a59ae"],
    ["環狀線", "#ffdb00"],
    ["淡海輕軌", "#8a2be2"],
    ["安坑輕軌", "#00a0a0"]
  ].freeze

  WIDTH = 900
  HEIGHT = 900
  PAD = 46

  def show
    @collection = Collection.find_by(kind: :everyday)
    @lines = LINES
    @stations = ordered_stations
    @placed = @stations.values.flatten.uniq.select { |lexeme| lexeme.data["lat"].present? }
    @points = project(@placed)
    @cards = @placed.index_by(&:text).transform_values { |lexeme| card_for(lexeme) }
    @segments = @stations.transform_values { |stations| segments_for(stations) }
  end

  def segments_for(stations)
    points = stations.filter_map { |lexeme| @points[lexeme.text] }
    return [] if points.size < 2

    hops = points.each_cons(2).map { |a, b| Math.hypot(b[0] - a[0], b[1] - a[1]) }
    typical = hops.sort[hops.size / 2]
    limit = [typical * 3, 40].max

    points
      .each_with_index
      .slice_when { |(_, index), _| hops[index] && hops[index] > limit }
      .map { |group| group.map(&:first) }
      .select { |segment| segment.size > 1 }
  end

  def project(stations)
    return {} if stations.empty?

    lats = stations.map { |lexeme| lexeme.data["lat"].to_f }
    lons = stations.map { |lexeme| lexeme.data["lon"].to_f }
    lat_span = [lats.max - lats.min, 0.0001].max
    lon_span = [lons.max - lons.min, 0.0001].max
    scale = [(WIDTH - (PAD * 2)) / lon_span, (HEIGHT - (PAD * 2)) / lat_span].min

    stations.to_h { |lexeme|
      x = PAD + ((lexeme.data["lon"].to_f - lons.min) * scale)
      y = HEIGHT - PAD - ((lexeme.data["lat"].to_f - lats.min) * scale)
      [lexeme.text, [x.round(1), y.round(1)]]
    }
  end

  private

  def ordered_stations
    return {} if @collection.nil?

    scope = @collection
      .lexemes
      .where("lexemes.data -> 'lines' IS NOT NULL")
      .order(Arel.sql("collection_items.position"))
      .to_a

    LINES.to_h { |name, _|
      on_line = scope.select { |lexeme| lexeme.data["lines"].is_a?(Hash) && lexeme.data["lines"].key?(name) }
      [name, on_line.sort_by { |lexeme| lexeme.data["lines"][name].to_i }]
    }
  end

  def line_names(lexeme)
    lines = lexeme.data["lines"]
    names = lines.is_a?(Hash) ? lines.keys : Array(lines)
    order = LINES.map(&:first)
    names.sort_by { |name| order.index(name) || order.size }
  end

  def card_for(lexeme)
    {
      text: lexeme.text,
      zhuyin: lexeme.readings["zhuyin"],
      pinyin: lexeme.readings["pinyin"],
      meaning: lexeme.meaning(I18n.locale),
      lines: line_names(lexeme),
      abbr: lexeme.data.dig("abbr", "text"),
      abbrReading: lexeme.data.dig("abbr", "zhuyin") || lexeme.data.dig("abbr", "pinyin"),
      href: dict_entry_path(lexeme.text)
    }
  end
end
