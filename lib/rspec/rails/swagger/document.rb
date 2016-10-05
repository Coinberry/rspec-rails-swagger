module RSpec
  module Rails
    module Swagger
      class Document
        attr_accessor :data

        def initialize(data)
          @data = data.deep_symbolize_keys
        end

        def [](value)
          data[value]
        end

        ##
        # Look up parameter or definition references.
        def resolve_ref(ref)
          unless %r{#/(?<location>parameters|definitions)/(?<name>.+)} =~ ref
            raise ArgumentError, "Invalid reference: #{ref}"
          end

          result = data.fetch(location.to_sym, {})[name.to_sym]
          raise ArgumentError, "Reference value does not exist: #{ref}" unless result

          if location == 'parameters'
            result.merge(name: name)
          end

          result
        end
      end
    end
  end
end
