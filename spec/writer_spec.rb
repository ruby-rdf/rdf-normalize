$:.unshift "."
require 'spec_helper'
require 'rdf/spec/writer'

describe RDF::Normalize::Writer do
  # @see lib/rdf/spec/writer.rb in rdf-spec
  it_behaves_like 'an RDF::Writer' do
    let(:writer) { described_class.new }
  end

  describe ".for" do
    it "discovers with :normalize" do
      expect(RDF::Writer.for(:normalize)).to eql described_class
    end
  end

  [:carroll2001, :urdna2015].each do |algorithm|
    describe algorithm do
      describe "json-ld normalization tests" do
        Dir.glob(File.expand_path("../data/normalize*-in.jsonld", __FILE__)).each do |input|
          it "produces expected output for #{input.split('/').last}" do
            expected = File.read(input.sub("-in.jsonld", "-#{algorithm == :urdna2015 ? 'out' : algorithm.to_s[0..-5]}.nq"))
            input_data = File.read(input)
            repo = RDF::Repository.load(input)
            result = repo.dump(:normalize, algorithm: algorithm)
            expect(result).to produce(expected, about: input, input: input_data)
          end
        end
      end
    end
  end
end