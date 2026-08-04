# frozen_string_literal: true

class JsonData
  ROOTS = {data: :path, media: :media_path}.freeze

  def initialize(relative, default: {}, watch: false, root: :data)
    @relative = relative
    @default = default.freeze
    @watch = watch
    @resolver = ROOTS.fetch(root)
  end

  def path = AppData.public_send(@resolver, @relative)

  def exist? = path.exist?

  def value
    return @value if fresh?

    @stamp = stamp
    @value = read
  end

  def reset!
    remove_instance_variable(:@value) if defined?(@value)
    @stamp = nil
  end

  private

  def fresh?
    return false unless defined?(@value)

    !@watch || @stamp == stamp
  end

  def stamp
    here = path
    here.exist? ? here.mtime : nil
  end

  def read
    here = path
    return @default.dup unless here.exist?

    JSON.parse(here.read)
  rescue JSON::ParserError => e
    Rails.logger.error("#{@relative} could not be read: #{e.class}: #{e.message}")
    @default.dup
  end
end
