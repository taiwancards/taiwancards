# frozen_string_literal: true

module LanguageFlagHelper
  FLAGS = {
    "en" => <<~SVG,
      <rect width="24" height="18" fill="#b22234"/>
      <path d="M0 2.08H24M0 4.85H24M0 7.62H24M0 10.38H24M0 13.15H24M0 15.92H24" stroke="#fff" stroke-width="1.385"/>
      <rect width="10.4" height="9.69" fill="#3c3b6e"/>
      <path stroke="#fff" stroke-width=".9" stroke-linecap="round" d="M1.2 1.6h0M3.2 1.6h0M5.2 1.6h0M7.2 1.6h0M9.2 1.6h0M2.2 3.2h0M4.2 3.2h0M6.2 3.2h0M8.2 3.2h0M1.2 4.85h0M3.2 4.85h0M5.2 4.85h0M7.2 4.85h0M9.2 4.85h0M2.2 6.5h0M4.2 6.5h0M6.2 6.5h0M8.2 6.5h0M1.2 8.1h0M3.2 8.1h0M5.2 8.1h0M7.2 8.1h0M9.2 8.1h0"/>
    SVG
      "vi" => <<~SVG,
      <rect width="24" height="18" fill="#da251d"/>
      <path fill="#ff0" d="M12 3l1.35 4.15h4.36l-3.53 2.56 1.35 4.14L12 11.29l-3.53 2.56 1.35-4.14-3.53-2.56h4.36z"/>
    SVG
      "ru" => <<~SVG
      <rect width="24" height="6" fill="#fff"/>
      <rect y="6" width="24" height="6" fill="#0039a6"/>
      <rect y="12" width="24" height="6" fill="#d52b1e"/>
    SVG
  }.freeze

  def flagged_languages = FLAGS.keys

  def language_flag(code, css: nil)
    tag.svg(
      FLAGS.fetch(code.to_s).html_safe,
      viewBox: "0 0 24 18",
      class: "h-[18px] w-6 overflow-hidden rounded-[3px] ring-1 ring-border #{css}".strip,
      aria: {hidden: true}
    )
  end
end
