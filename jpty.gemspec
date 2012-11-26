# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jpty/version'

Gem::Specification.new do |gem|
  gem.name          = "jpty"
  gem.version       = JPTY::VERSION
  gem.authors       = ["Kazuhiro Yamada"]
  gem.email         = ["kyamada@sonix.asia"]
  gem.description   = %q{PTY for jruby}
  gem.summary       = %q{PTY for jruby using expectj}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_development_dependency 'rspec'
end
