require_relative 'spec_helper'
require 'rdf/spec/writer'

describe RDF::Normalize::Writer do
  let(:logger) {RDF::Spec.logger}

  # @see lib/rdf/spec/writer.rb in rdf-spec
  it_behaves_like 'an RDF::Writer' do
    let(:writer) { RDF::Normalize::Writer.new }
  end

  describe ".for" do
    it "discovers with :normalize" do
      expect(RDF::Writer.for(:normalize)).to eql described_class
    end
  end
end