require 'fileutils'
require_relative 'spec_helper'

describe RDF::Normalize::Writer do
  require_relative 'suite_helper'

  %w(urgna2012 urdna2015).each do |variant|
    describe "w3c Normalization #{variant.upcase} tests" do
      manifest = Fixtures::SuiteTest::BASE + "manifest-#{variant}.jsonld"

      Fixtures::SuiteTest::Manifest.open(manifest, manifest[0..-8]) do |m|
        describe m.comment do
          m.entries.each do |t|
            specify "#{t.id.split("/").last}: #{t.name} - #{t.comment}" do
              t.logger = RDF::Spec.logger
              dataset = RDF::Repository.load(t.action, format: :nquads)
              result = dataset.dump(:normalize, logger: t.logger, **t.writer_options)
              expect(result).to produce(t.expected, t)
            end
          end
        end
      end
    end
  end
end unless ENV['CI']  # Skip for continuous integration