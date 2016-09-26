require 'rspec/core/formatters/base_text_formatter'

module RSpec
  module Swagger
    class Formatter < RSpec::Core::Formatters::BaseTextFormatter
      RSpec::Core::Formatters.register self, :example_finished, :close

      def documents
        # We don't try to load the docs in `initalize` because when running
        # `rspec -f RSpec::Swagger::Formatter` RSpec initalized this class
        # before `swagger_helper` has run.
        @documents ||= ::RSpec.configuration.swagger_docs
      end

      def example_finished(notification)
        metadata  = notification.example.metadata
        return unless metadata[:swagger_object] == :response

        # metadata.each do |k, v|
        #   puts "#{k}\t#{v}" if k.to_s.starts_with?("swagger")
        # end

        document  = document_for(metadata[:swagger_document])
        path_item = path_item_for(document, metadata[:swagger_path_item])
        operation = operation_for(path_item, metadata[:swagger_operation])
                    response_for(operation, metadata[:swagger_response])
      end

      def close(_notification)
        documents.each{|k, v| write_json(k, v)}
      end

      def write_json(name, document)
        root = ::RSpec.configuration.swagger_root
        # It would be good to at least warn if the name includes some '../' that
        # takes it out of root directory.
        target = Pathname(name).expand_path(root)
        target.dirname.mkpath
        target.write(JSON.pretty_generate(document))
      end

      def document_for(doc_name = nil)
        if doc_name
          documents.fetch(doc_name)
        else
          documents.values.first
        end
      end

      def path_item_for(document, swagger_path_item)
        name = swagger_path_item[:path]

        document[:paths] ||= {}
        document[:paths][name] ||= {}
        if swagger_path_item[:parameters]
          document[:paths][name][:parameters] = prepare_parameters(swagger_path_item[:parameters])
        end
        document[:paths][name]
      end

      def operation_for(path, swagger_operation)
        method = swagger_operation[:method]

        path[method] ||= {responses: {}}
        path[method].tap do |operation|
          if swagger_operation[:parameters]
            operation[:parameters] = prepare_parameters(swagger_operation[:parameters])
          end
          operation.merge!(swagger_operation.slice(
            :summary, :description, :externalDocs, :operationId,
            :consumes, :produces, :schemes, :deprecated, :security
          ))
        end
      end

      def response_for(operation, swagger_response)
        status = swagger_response[:status_code]

        operation[:responses][status] ||= {}
        operation[:responses][status].tap do |response|
          if swagger_response[:examples]
            response[:examples] = prepare_examples(swagger_response[:examples])
          end
          response.merge!(swagger_response.slice(:description, :schema, :headers))
        end
      end

      def prepare_parameters(params)
        params.values
      end

      def prepare_examples(examples)
        if examples["application/json"].present?
          begin
            examples["application/json"] = JSON.parse(examples["application/json"])
          rescue JSON::ParserError
          end
        end
        examples
      end
    end
  end
end
