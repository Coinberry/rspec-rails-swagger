require 'swagger_helper'

RSpec.describe RSpec::Swagger::Helpers::Paths do
  let(:klass) do
    Class.new do
      include RSpec::Swagger::Helpers::Paths
      attr_accessor :metadata
      def describe *args ; end
    end
  end
  subject { klass.new }

  it "requires the path start with a /" do
    expect{ subject.path("foo") }.to raise_exception(ArgumentError)
    expect{ subject.path("/foo") }.not_to raise_exception
  end

  it "defaults to the first swagger document if not specified" do
    expect(subject).to receive(:describe).with("/ping", {
      swagger_object: :path_item,
      swagger_document: RSpec.configuration.swagger_docs.keys.first,
      swagger_path_item: {path: '/ping'}
    })

    subject.path('/ping')
  end

  it "accepts specified swagger document name" do
    expect(subject).to receive(:describe).with("/ping", {
      swagger_object: :path_item,
      swagger_document: 'hello_swagger.json',
      swagger_path_item: {path: '/ping'}
    })

    subject.path('/ping', swagger_document: 'hello_swagger.json')
  end
end

RSpec.describe RSpec::Swagger::Helpers::PathItem do
  let(:klass) do
    Class.new do
      include RSpec::Swagger::Helpers::PathItem
      attr_accessor :metadata
      def describe *args ; end
    end
  end
  subject { klass.new }

  describe "#operation" do

    it "requires only an HTTP verb" do
      expect(subject).to receive(:describe).with('get', {
        swagger_object: :operation,
        swagger_operation: {method: :get}
      })

      subject.operation('GET')
    end

    it "accepts other options" do
      expect(subject).to receive(:describe).with('head', {
        swagger_object: :operation,
        swagger_operation: {
          method: :head, tags: ['pet'], summary: 'Updates',
          description: 'Updates a pet in the store with form data',
          operationId: 'updatePetWithForm'
        }
      })

      subject.operation('head',
        tags: ['pet'],
        summary: 'Updates',
        description: 'Updates a pet in the store with form data',
        operationId: 'updatePetWithForm'
      )
    end

  end
end

RSpec.describe RSpec::Swagger::Helpers::Parameters do
  let(:klass) do
    Class.new do
      include RSpec::Swagger::Helpers::Parameters
      attr_accessor :metadata
      def describe *args ; end
    end
  end
  subject { klass.new }

  describe "#parameter" do
    before { subject.metadata = {swagger_object: :path_item} }

    it "requires 'in' parameter" do
      expect{ subject.parameter("name", foo: :bar) }.to raise_exception(ArgumentError)
    end

    it "validates 'in' parameter" do
      expect{ subject.parameter("name", in: :form_data, type: :string) }.to raise_exception(ArgumentError)
      expect{ subject.parameter("name", in: "formData", type: :string) }.to raise_exception(ArgumentError)
      expect{ subject.parameter("name", in: :formData, type: :string) }.not_to raise_exception
    end

    it "requies a schema for body params" do
      expect{ subject.parameter(:name, in: :body) }.to raise_exception(ArgumentError)
      expect{ subject.parameter(:name, in: :body, schema: {ref: '#/definitions/foo'}) }.not_to raise_exception
    end

    it "requires a type for non-body params" do
      expect{ subject.parameter(:name, in: :path) }.to raise_exception(ArgumentError)
      expect{ subject.parameter(:name, in: :path, type: :number) }.not_to raise_exception
    end

    it "validates types" do
      %i(string number integer boolean array file).each do |type|
        expect{ subject.parameter(:name, in: :path, type: type) }.not_to raise_exception
      end
      [100, :pickles, "stuff"].each do |type|
        expect{ subject.parameter(:name, in: :path, type: type) }.to raise_exception(ArgumentError)
      end
    end

    it "marks path parameters as required" do
      subject.parameter("name", in: :path, type: :boolean)

      expect(subject.metadata[:swagger_path_item][:parameters].values.first).to include(required: true)
    end

    it "keeps parameters unique by name and location" do
      subject.parameter('foo', in: :path, type: :integer)
      subject.parameter('foo', in: :path, type: :integer)
      subject.parameter('bar', in: :query, type: :integer)
      subject.parameter('baz', in: :query, type: :integer)

      expect(subject.metadata[:swagger_path_item][:parameters].length).to eq 3
    end
  end
end


RSpec.describe RSpec::Swagger::Helpers::Operation do
  let(:klass) do
    Class.new do
      include RSpec::Swagger::Helpers::Operation
      attr_accessor :metadata
      def describe *args ; end
    end
  end
  subject { klass.new }

  describe "#response" do
    before { subject.metadata = {swagger_object: :operation} }

    it "requires code be an integer 100...600 or :default" do
      expect{ subject.response 99, description: "too low" }.to raise_exception(ArgumentError)
      expect{ subject.response 600, description: "too high" }.to raise_exception(ArgumentError)
      expect{ subject.response '404', description: "string" }.to raise_exception(ArgumentError)
      expect{ subject.response 'default', description: "string" }.to raise_exception(ArgumentError)

      expect{ subject.response 100, description: "low" }.not_to raise_exception
      expect{ subject.response 599, description: "high" }.not_to raise_exception
      expect{ subject.response :default, description: "symbol" }.not_to raise_exception
    end

    it "requires a description" do
      expect{ subject.response 100 }.to raise_exception(ArgumentError)
      expect{ subject.response 100, description: "low" }.not_to raise_exception
    end
  end
end


RSpec.describe RSpec::Swagger::Helpers::Resolver do
  # Tthis helper is an include rather than an extend we can get it pulled into
  # the test just by matching the filter metadata.
  describe("#resolve_params", :swagger_object) do
    let(:metadata) { {swagger_operation: {parameters: params}} }

    describe "with a missing value" do
      let(:params) { {"path&post_id" => {name: "post_id", in: :path}} }

      # TODO best thing would be to lazily evaulate the params so we'd only
      # hit this if something was trying to use it.
      it "raises an error" do
        expect{resolve_params(metadata, self)}.to raise_exception(NoMethodError)
      end
    end

    describe "with a valid value" do
      let(:params) { {"path&post_id" => {name: "post_id", in: :path, description: "long"}} }
      let(:post_id) { 123 }

      it "returns it" do
        expect(resolve_params(metadata, self)).to eq([{name: "post_id", in: :path, value: 123}])
      end
    end
  end

  describe "#resolve_path", :swagger_object do
    describe "with a missing value" do
      it "raises an error" do
        expect{ resolve_path('/sites/{site_id}', self) }.to raise_exception(NoMethodError)
      end
    end

    describe "with values" do
      let(:site_id) { 1001 }
      let(:accountId) { "pickles" }

      it "substitutes them into the path" do
        expect(resolve_path('/sites/{site_id}/accounts/{accountId}', self)).to eq('/sites/1001/accounts/pickles')
      end
    end

    describe "with a base path" do
      xit "prefixes the path" do

      end
    end
  end

  describe "#resolve_headers", :swagger_object do
    context "with consumes set" do
      let(:metadata) { {swagger_operation: {consumes: ['application/json']}} }

      it "sets the Content-Type header" do
        expect(resolve_headers(metadata)).to include('CONTENT_TYPE' => 'application/json')
      end
    end

    context "with produces set" do
      let(:metadata) { {swagger_operation: {produces: ['application/xml']}} }

      it "sets the Accepts header" do
        expect(resolve_headers(metadata)).to include('HTTP_ACCEPT' => 'application/xml')
      end
    end

    xit "includes paramters" do

    end
  end
end
