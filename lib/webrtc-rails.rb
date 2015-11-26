require 'webrtc_rails/daemon'
require 'webrtc_rails/server_message'
require 'webrtc_rails/engine'
require 'webrtc_rails/configuration'
require 'webrtc_rails/version'

module WebrtcRails
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= WebrtcRails::Configuration.new
    yield(configuration)
  end
end
