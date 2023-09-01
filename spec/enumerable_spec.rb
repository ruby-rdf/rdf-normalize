require_relative 'spec_helper'
require 'rdf/spec/format'
require 'rdf/normalize'

describe RDF::Enumerable do
  describe "#canonicalize" do
    it "normalizes with an enumerator" do
      input =  RDF::Spec.quads.extend(RDF::Enumerable)
      expect(RDF::Normalize).to receive(:new)
          .with(RDF::Enumerable::Enumerator)

      input.canonicalize
    end
  end
end
