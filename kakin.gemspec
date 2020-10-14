# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kakin/version'

Gem::Specification.new do |spec|
  spec.name          = "kakin"
  spec.version       = Kakin::VERSION
  spec.authors       = ["buty4649", "SHIBATA Hiroshi"]
  spec.email         = ["", "hsbt@ruby-lang.org"]

  spec.summary       = %q{kakin is resource calcuration tool for OpenStack}
  spec.description   = %q{kakin is resource calcuration tool for OpenStack}
  spec.homepage      = "https://github.com/yaocloud/kakin"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'thor'
  spec.add_dependency 'yao', ">= 0.13.4"

  spec.add_development_dependency "bundler", "~> 2.1.4"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "minitest"
end
