require 'json'

module DataMapper
  module Types
    class Json < DataMapper::Type
      primitive String
      size 65535
      lazy true

      def self.load(value, property)
        if value.nil?
          nil
        elsif value.is_a?(String)
          ::JSON.load(value)
        else
          raise ArgumentError.new("+value+ must be nil or a String")
        end
      end

      def self.dump(value, property)
        if value.nil?
          nil
        elsif value.is_a?(String)
          value
        else
          ::JSON.dump(value)
        end
      end
    end # class Json
  end # module Types
end # module DataMapper
