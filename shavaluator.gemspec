# encoding: utf-8
$:.unshift File.expand_path("../lib", __FILE__)
require 'shavaluator/version'

Gem::Specification.new do |s|
  s.name = 'parent_paths'
  s.licenses = ['MIT']
  s.summary = "Handy methods for scanning parent paths"
  s.version = Shavaluator::VERSION
  s.homepage = 'https://github.com/jeffomatic/shavaluator-rb'

  s.authors = ["Jeff Lee"]
  s.email = 'jeffomatic@gmail.com'

  s.files = %w( README.md LICENSE shavaluator.gemspec )
  s.files += Dir.glob('lib/**/*')

  s.add_development_dependency('rspec', '~>3.1.0')
  s.add_development_dependency('redis', '~>3.2.0')
end