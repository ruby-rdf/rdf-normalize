#!/usr/bin/env ruby
namespace :gem do
  desc "Build the rdf-normalize-#{File.read('VERSION').chomp}.gem file"
  task :build do
    sh "gem build rdf-normalize.gemspec && mv rdf-normalize-#{File.read('VERSION').chomp}.gem pkg/"
  end

  desc "Release the rdf-normalize-#{File.read('VERSION').chomp}.gem file"
  task :release do
    sh "gem push pkg/rdf-normalize-#{File.read('VERSION').chomp}.gem"
  end
end
