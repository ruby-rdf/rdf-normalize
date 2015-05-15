$:.unshift "."
require 'spec_helper'
require 'rdf/spec/format'

describe RDF::Normalize::Format do
  # @see lib/rdf/spec/format.rb in rdf-spec
  it_behaves_like 'an RDF::Format' do
    let(:format_class) { described_class }
  end

  describe ".for" do
    formats = [
      :normalize,
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        RDF::Format.for(arg).should == described_class
      end
    end
  end

  describe "#to_sym" do
    specify {described_class.to_sym.should == :normalize}
  end
end
