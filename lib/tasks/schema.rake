# frozen_string_literal: true

namespace :schema do
  SCHEMA = Rails.root.join("db/schema.rb")
  CONFIG = Rails.root.join(".rubocop_schema.yml")
  WIDTH = 120
  CALL = /\A(\s*)([\w.]+)\((.*)\)\z/

  def top_level_commas(arguments)
    depth = 0
    quote = nil
    arguments.each_char.with_index.with_object([]) do |(char, index), positions|
      if quote
        quote = nil if char == quote
      elsif %w[" '].include?(char)
        quote = char
      elsif "([{".include?(char)
        depth += 1
      elsif ")]}".include?(char)
        depth -= 1
      elsif char == "," && depth.zero?
        positions << index
      end
    end
  end

  def split_arguments(arguments)
    cuts = top_level_commas(arguments)
    bounds = [-1, *cuts, arguments.length]
    bounds.each_cons(2).map { |from, to| arguments[(from + 1)...to].strip }
  end

  def wrap(line)
    return line if line.length <= WIDTH

    indent, receiver, arguments = line.match(CALL)&.captures
    return line if indent.nil?

    parts = split_arguments(arguments)
    return line if parts.length < 2

    ["#{indent}#{receiver}(", *parts.map { |part| "#{indent}  #{part}," }, "#{indent})"]
      .then { |rows| rows[-2] = rows[-2].delete_suffix(","); rows }
      .join("\n")
  end

  desc "Restore the repository formatting of db/schema.rb after a dump"
  task :format do
    system("bundle", "exec", "rubocop", "-a", "-c", CONFIG.to_s, SCHEMA.to_s, out: File::NULL, exception: true)
    SCHEMA.write("#{SCHEMA.each_line.map { |line| wrap(line.chomp) }.join("\n")}\n")
  end
end

%w[db:migrate db:rollback db:schema:dump].each do |name|
  Rake::Task[name].enhance { Rake::Task["schema:format"].invoke } if Rake::Task.task_defined?(name)
end
