# frozen_string_literal: true

module Huayu
  module Traditional
    HAN = /\p{Han}/

    module_function

    def char?(char)
      char.encode("Big5")
      true
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      false
    end

    def only?(text)
      simplified(text).empty?
    end

    def simplified(text)
      text.to_s.each_char.select { |char| char.match?(HAN) && !char?(char) }.uniq
    end
  end
end
