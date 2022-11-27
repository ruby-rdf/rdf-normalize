require_relative 'spec_helper'
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
        expect(RDF::Format.for(arg)).to eql described_class
      end
    end
  end

  describe "#to_sym" do
    specify {expect(described_class.to_sym).to eql :normalize}
  end
end
