require 'fileutils'
require_relative 'spec_helper'

describe RDF::Normalize::Writer do
  require_relative 'suite_helper'

  %w(rdfc10 rdfc10map).each do |variant|
    describe "w3c Normalization #{variant.upcase} tests" do
      manifest = Fixtures::SuiteTest::BASE + "manifest-#{variant}.jsonld"

      Fixtures::SuiteTest::Manifest.open(manifest, manifest[0..-8]) do |m|
        describe m.comment do
          m.entries.each do |t|
            specify "#{t.id.split("/").last}: #{t.name} - #{t.comment}" do
              t.logger = RDF::Spec.logger
              dataset = RDF::Repository.load(t.action, format: :nquads)
              if t.type == 'rdfc:RDFC10MapTest'
                input_map = RDF::Normalize::RDFC10.new(dataset).to_hash
                result_map = JSON.load(t.expected)
                expect(input_map).to produce(result_map, t)
              else
                result = dataset.dump(:normalize, logger: t.logger, **t.writer_options)
                expect(result).to produce(t.expected, t)
              end
            end
          end
        end
      end
    end
  end
end unless ENV['CI']  # Skip for continuous integration