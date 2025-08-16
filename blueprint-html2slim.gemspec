require_relative 'lib/blueprint/html2slim/version'

Gem::Specification.new do |spec|
  spec.name          = 'blueprint-html2slim'
  spec.version       = Blueprint::Html2Slim::VERSION
  spec.authors       = ['Vladimir Elchinov']
  spec.email         = ['info@railsblueprint.com']

  spec.summary       = 'Convert HTML and ERB files to Slim format'
  spec.description   = 'A Ruby command-line tool to convert HTML and ERB files to Slim format ' \
                       'with smart naming conventions and backup options'
  spec.homepage      = 'https://github.com/railsblueprint/html2slim'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/railsblueprint/html2slim'
  spec.metadata['changelog_uri'] = 'https://github.com/railsblueprint/html2slim/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{bin,lib}/**/*', 'LICENSE', 'README.md', 'CHANGELOG.md'].reject { |f| File.directory?(f) }
  end

  spec.bindir        = 'bin'
  spec.executables   = %w[html2slim slimtool]
  spec.require_paths = ['lib']

  spec.add_dependency 'erubi', '~> 1.12'
  spec.add_dependency 'nokogiri', '~> 1.16'
  spec.add_dependency 'thor', '~> 1.3'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-rake', '~> 0.6'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.22'
end
