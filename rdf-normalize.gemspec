#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "rdf-normalize"
  gem.homepage              = "http://github.com/gkellogg/rdf-normalize"
  gem.license               = 'Public Domain' if gem.respond_to?(:license=)
  gem.summary               = "RDF Graph normalizer for Ruby."
  gem.description           = %q{RDF::Normalize is a Graph normalizer for the RDF.rb library suite.}
  gem.rubyforge_project     = 'rdf-normalize'

  gem.authors               = ['Gregg Kellogg']
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README.md LICENSE VERSION) + Dir.glob('lib/**/*.rb')
  #gem.bindir               = %q(bin)
  #gem.default_executable   = gem.executables.first
  gem.require_paths         = %w(lib)
  gem.extensions            = %w()
  gem.test_files            = %w()
  gem.has_rdoc              = false

  gem.required_ruby_version = '>= 2.0.0'
  gem.add_dependency             'rdf',             '~> 1.99'
  gem.add_development_dependency 'rdf-spec',        '~> 1.99'
  gem.add_development_dependency 'open-uri-cached', '~> 0.0', '>= 0.0.5'
  gem.add_development_dependency 'rspec',           '~> 3.2'
  gem.add_development_dependency 'webmock',         '~> 1.17'
  gem.add_development_dependency 'json-ld',         '~> 1.99'
  gem.add_development_dependency 'yard' ,           '~> 0.8'
  gem.post_install_message  = nil
end