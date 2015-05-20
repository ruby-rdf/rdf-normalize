$:.unshift "."
require 'spec_helper'
require 'rdf/spec/writer'

describe RDF::Normalize::Writer do
  # @see lib/rdf/spec/writer.rb in rdf-spec
  it_behaves_like 'an RDF::Writer' do
    let(:writer) { RDF::Normalize::Writer.new }
  end

  before(:each) do
    @debug = []
  end

  describe ".for" do
    it "discovers with :normalize" do
      expect(RDF::Writer.for(:normalize)).to eql described_class
    end
  end

  # FIXME: :carroll2001, 
  [:urgna2012, :urdna2015].each do |algorithm|
    describe algorithm do
      describe "w3c normalization tests" do
        Dir.glob(File.expand_path("../data/*-in.nq", __FILE__)).each do |input|
          next unless File.exist?(input.sub("-in", "-#{algorithm}"))
          it "produces expected output for #{input.split('/').last}" do
            expected = File.read(input.sub("-in", "-#{algorithm}"))
            input_data = File.read(input)
            repo = RDF::Repository.load(input)
            result = repo.dump(:normalize, algorithm: algorithm, debug: @debug)
            expect(result).to produce(expected, about: input, quads: repo.dump(:nquads), trace: @debug)
          end
        end
      end
    end
  end
end