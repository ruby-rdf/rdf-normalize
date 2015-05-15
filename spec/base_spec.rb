$:.unshift "."
require 'spec_helper'

describe RDF::Normalize::Base do
  subject {RDF::Normalize.new(Graph.new)}
  describe ".new" do
    it "is an RDF::Enumerable" do
      
    end
  end
  
  describe "#supports?" do
    it "context" do
      subject.supports(:context).should be_true
    end
  end
  
  context "triples" do
  end
  
  context "quads" do
  end
end