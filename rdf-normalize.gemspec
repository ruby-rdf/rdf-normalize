#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "rdf-normalize"
  gem.homepage              = "https://github.com/ruby-rdf/rdf-normalize"
  gem.license               = 'Unlicense'
  gem.summary               = "RDF Graph normalizer for Ruby."
  gem.description           = %q{RDF::Normalize performs Dataset Canonicalization for RDF.rb.}
  gem.metadata           = {
    "documentation_uri" => "https://ruby-rdf.github.io/rdf-normalize",
    "bug_tracker_uri"   => "https://github.com/ruby-rdf/rdf-normalize/issues",
    "homepage_uri"      => "https://github.com/ruby-rdf/rdf-normalize",
    "mailing_list_uri"  => "https://lists.w3.org/Archives/Public/public-rdf-ruby/",
    "source_code_uri"   => "https://github.com/ruby-rdf/rdf-normalize",
  }

  gem.authors               = ['Gregg Kellogg']
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README.md LICENSE VERSION) + Dir.glob('lib/**/*.rb')
  gem.require_paths         = %w(lib)

  gem.required_ruby_version = '>= 3.0'
  gem.add_dependency             'rdf',             '~> 3.3'
  gem.add_development_dependency 'base64',          '~> 0.2'
  gem.add_development_dependency 'getoptlong',      '~> 0.2'
  gem.add_development_dependency 'rdf-spec',        '~> 3.3'
  gem.add_development_dependency 'rspec',           '~> 3.12'
  gem.add_development_dependency 'json-ld',         '~> 3.3'
  gem.add_development_dependency 'rdf-trig',        '~> 3.3'
  gem.add_development_dependency 'yard' ,           '~> 0.9'
  gem.post_install_message  = nil
end
