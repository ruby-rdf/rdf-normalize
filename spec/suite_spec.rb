require 'fileutils'
require_relative 'spec_helper'

describe RDF::Normalize::Writer do
  require_relative 'suite_helper'

  describe "w3c RDFC 1.0 tests" do
    manifest = Fixtures::SuiteTest::BASE + "manifest.jsonld"

    Fixtures::SuiteTest::Manifest.open(manifest, manifest[0..-8]) do |m|
      describe m.comment do
        m.entries.each do |t|
          specify "#{t.id.split("/").last}: #{t.name} - #{t.comment}" do
            t.logger = RDF::Spec.logger
            dataset = RDF::Repository.load(t.action, format: :nquads)
            if t.type == 'rdfc:RDFC10MapTest'
              input_map = RDF::Normalize::RDFC10.new(dataset, **t.writer_options).to_hash
              result_map = JSON.load(t.expected)
              expect(input_map).to produce(result_map, t)
            elsif t.type == 'rdfc:RDFC10NegativeEvalTest'
              expect {RDF::Normalize::RDFC10.new(dataset).to_hash}.to raise_error(::RDF::Normalize::MaxCallsExceeded)
            else
              result = dataset.dump(:normalize, logger: t.logger, **t.writer_options)
              expect(result).to produce(t.expected, t)
            end
          end
        end
      end
    end
  end
end unless ENV['CI']  # Skip for continuous integration