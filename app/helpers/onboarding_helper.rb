# frozen_string_literal: true

module OnboardingHelper
  def roadmap_link_for(step)
    route = step[:route]
    route && public_send(route)
  end

  def roadmap_step_classes(state)
    case state
    when :done
      "border-border bg-muted/40"
    when :current
      "border-primary bg-card shadow-sm"
    else
      "border-border bg-card"
    end
  end
end
