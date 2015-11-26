require 'webrtc_rails/server_message'
require 'webrtc_rails/version'

module WebrtcRails
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load "tasks/webrtc_rails.rake"
    end
  end
end
