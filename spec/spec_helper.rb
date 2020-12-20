$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift File.dirname(__FILE__)

require "bundler/setup"
require 'rspec'
require 'json/ld'
require 'rdf/spec'
require 'rdf/normalize'
require 'rdf/nquads'
require 'webmock/rspec'

begin
  require 'simplecov'
  require 'coveralls'
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ])
  SimpleCov.start do
    add_filter "/spec/"
  end
  Coveralls.wear!
rescue LoadError => e
  STDERR.puts "Coverage Skipped: #{e.message}"
end

::RSpec.configure do |c|
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
  c.include(RDF::Spec::Matchers)
end
