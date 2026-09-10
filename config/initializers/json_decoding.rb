# frozen_string_literal: true

module JsonKeywordDecoding
  def decode(json, options = {})
    data = ::JSON.parse(json, **options)
    ActiveSupport.parse_json_times ? convert_dates_from(data) : data
  end

  alias_method :load, :decode
end

ActiveSupport::JSON.singleton_class.prepend(JsonKeywordDecoding)
