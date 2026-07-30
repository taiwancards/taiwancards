# frozen_string_literal: true

module ToneChartHelper
  CONTOURS = {
    "taipei" => {
      "t1" => {points: [[0, 4], [1, 4]], label: nil},
      "t2" => {points: [[0, 3], [0.45, 2.4], [1, 3.4]], label: nil},
      "t3" => {points: [[0, 3], [0.5, 1], [1, 1]], label: nil},
      "t4" => {points: [[0, 5], [1, 2]], label: nil}
    }.freeze,
    "beijing" => {
      "t1" => {points: [[0, 5], [1, 5]], label: "55"},
      "t2" => {points: [[0, 3], [1, 5]], label: "35"},
      "t3" => {points: [[0, 2], [0.45, 1], [1, 3.6]], label: "214"},
      "t4" => {points: [[0, 5], [1, 1]], label: "51"}
    }.freeze
  }.freeze

  WIDTH = 88
  HEIGHT = 96
  PAD_X = 14
  PAD_Y = 12

  def tone_chart(variant, tone)
    contour = CONTOURS.fetch(variant).fetch(tone)

    tag.svg(
      viewBox: "0 0 #{WIDTH} #{HEIGHT}",
      role: "img",
      class: "h-24 w-22",
      "aria-label": t("tones.chart.aria", tone: t("tones.tones.#{tone}.name"))
    ) do
      safe_join([tone_staff, tone_path(contour[:points]), tone_dot(contour[:points].last)])
    end
  end

  private

  def tone_x(value) = PAD_X + (value * (WIDTH - (PAD_X * 2)))

  def tone_y(level) = HEIGHT - PAD_Y - ((level - 1) / 4.0 * (HEIGHT - (PAD_Y * 2)))

  def tone_staff
    safe_join(
      (1..5).map { |level|
        tag.line(
          x1: PAD_X - 6,
          x2: WIDTH - PAD_X + 6,
          y1: tone_y(level),
          y2: tone_y(level),
          stroke: "currentColor",
          "stroke-width": level == 1 || level == 5 ? 1 : 0.5,
          opacity: level == 1 || level == 5 ? 0.35 : 0.15
        )
      }
    )
  end

  def tone_path(points)
    coords = points.map { |x, level| [tone_x(x).round(1), tone_y(level).round(1)] }
    d = coords.each_with_index.map { |(x, y), index| "#{index.zero? ? "M" : "L"}#{x} #{y}" }.join(" ")

    tag.path(
      d:,
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 3.5,
      "stroke-linecap": "round",
      "stroke-linejoin": "round"
    )
  end

  def tone_dot(point)
    x, level = point
    tag.circle(cx: tone_x(x).round(1), cy: tone_y(level).round(1), r: 3.5, fill: "currentColor")
  end
end
