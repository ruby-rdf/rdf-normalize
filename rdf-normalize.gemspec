#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "rdf-normalize"
  gem.homepage              = "http://github.com/gkellogg/rdf-normalize"
  gem.license               = 'Unlicense'
  gem.summary               = "RDF Graph normalizer for Ruby."
  gem.description           = %q{RDF::Normalize is a Graph normalizer for the RDF.rb library suite.}
  gem.rubyforge_project     = 'rdf-normalize'

  gem.authors               = ['Gregg Kellogg']
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README.md LICENSE VERSION) + Dir.glob('lib/**/*.rb')
  gem.require_paths         = %w(lib)

  gem.required_ruby_version = '>= 2.2.2'
  gem.add_dependency             'rdf',             '~> 3.0'
  gem.add_development_dependency 'rdf-spec',        '~> 3.0'
  gem.add_development_dependency 'open-uri-cached', '~> 0.0', '>= 0.0.5'
  gem.add_development_dependency 'rspec',           '~> 3.7'
  gem.add_development_dependency 'webmock',         '~> 3.0'
  #gem.add_development_dependency 'json-ld',         '~> 3.0'
  gem.add_development_dependency 'json-ld',         '>= 2.2', '< 4.0'
  gem.add_development_dependency 'yard' ,           '~> 0.9.12'
  gem.post_install_message  = nil
end
