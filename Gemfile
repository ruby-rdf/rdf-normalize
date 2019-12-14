source "https://rubygems.org"

gemspec

gem "rdf", github: "ruby-rdf/rdf", branch: "develop"

group :debug do
  gem "byebug", platforms: :mri
end

group :development, :test do
  gem 'json-ld',        github: "ruby-rdf/json-ld",   branch: "develop"
  gem 'rdf-isomorphic', github: "ruby-rdf/rdf-isomorphic",  branch: "develop"
  gem 'rdf-spec',       github: "ruby-rdf/rdf-spec",  branch: "develop"
end

group :development, :test do
  gem 'psych', :platforms => [:mri, :rbx]
end
