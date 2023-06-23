require_relative 'spec_helper'

describe RDF::Normalize::RDFC10 do
  let(:logger) {RDF::Spec.logger}

  describe "w3c normalization tests – identifier map" do
    Dir.glob(File.expand_path("../data/*-in.nq", __FILE__)).each do |input|
      next unless File.exist?(input.sub("-in.nq", "-rdfc10map.json"))
      it "produces expected output for #{input.split('/').last}" do
        repo = RDF::Repository.load(input)
        expected = File.read(input.sub("-in.nq", "-rdfc10map.json"))
        input_map = RDF::Normalize::RDFC10.new(repo).to_hash
        result_map = JSON.load(expected)
        expect(input_map).to produce(result_map, id: input, logger: logger)
      end
    end
  end
end