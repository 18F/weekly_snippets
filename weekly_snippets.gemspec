# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'weekly_snippets/version'

Gem::Specification.new do |s|
  s.name          = 'weekly_snippets'
  s.version       = WeeklySnippets::VERSION
  s.authors       = ['Mike Bland']
  s.email         = ['michael.bland@gsa.gov']
  s.summary       = 'Standardize, munge, redact, and publish weekly snippets'
  s.description   = (
    'Standardizes different weekly snippet formats into a common format, ' +
    'munges snippet text according to user-supplied rules, performs ' +
    'redaction of internal information, and publishes snippets in ' +
    'plaintext or Markdown format.')
  s.homepage      = 'https://github.com/18F/weekly_snippets'
  s.license       = 'CC0'

  s.files         = `git ls-files -z README.md lib`.split("\x0")

  s.add_development_dependency 'bundler', '~> 1.7'
  s.add_development_dependency 'rake', '~> 10.0'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'codeclimate-test-reporter'
end
