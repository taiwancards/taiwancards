# frozen_string_literal: true

module NamesHelper
  def names_chip_class(active)
    base = "rounded-full border px-3 py-1.5 text-xs font-medium"
    active ? "#{base} border-primary bg-primary text-primary-foreground" : "#{base} border-border hover:bg-muted"
  end

  def names_assistant_copy
    {
      vibes: Huayu::TaiwanNames::FIELDS.index_with { |field| t("names.assistant.vibes.#{field}") },
      why: t("names.assistant.why").transform_keys(&:to_s)
    }
  end
end
