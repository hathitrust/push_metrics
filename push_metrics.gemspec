# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "push_metrics"
  spec.version = "0.10.0"
  spec.authors = ["Aaron Elkiss"]
  spec.email = ["aelkiss@umich.edu"]

  spec.summary = "Tracks and reports progress for batch processing to a Prometheus push gateway."
  spec.homepage = "https://github.com/hathitrust/push_metrics"
  spec.license = "BSD-3-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage + "/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html

  spec.add_dependency "milemarker", "~> 1.0"
  spec.add_dependency "prometheus-client", "~> 4.0"

  spec.add_development_dependency "bundler", "~>2.0"
  spec.add_development_dependency "climate_control"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", "~>13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "standardrb"
  spec.add_development_dependency "faraday", "~> 2.7"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-lcov"
end
