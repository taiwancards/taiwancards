# frozen_string_literal: true

module RubyUI
  extend Phlex::Kit
end

Rails.autoloaders.main.inflector.inflect(
  "ruby_ui" => "RubyUI"
)

Rails.autoloaders.main.push_dir(
  Rails.root.join("app/components/ruby_ui"),
  namespace: RubyUI
)

Rails.autoloaders.main.collapse(Rails.root.join("app/components/ruby_ui/*"))
