lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'webrtc_rails/version'

Gem::Specification.new do |spec|
  spec.name          = "webrtc-rails"
  spec.version       = WebrtcRails::VERSION
  spec.authors       = ["Koji Murata"]
  spec.email         = ["malt.koji@gmail.com"]

  spec.summary       = "Simple Ruby on Rails WebRTC integration."
  spec.description   = "webrtc-rails is a gem for easy to create video chat app."
  spec.homepage      = "https://github.com/malt03/webrtc-rails"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'em-websocket'
  spec.add_dependency 'daemons-rails'
  
  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
