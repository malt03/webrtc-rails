require 'rails'

module WebrtcRails
  module Generators
    class InstallGenerator < Rails::Generators::Base
      def add_gems
        gem 'daemons-rails'
        gem 'em-websocket'
      end

      def injection
        generate 'webrtc_rails:injection'
      end
    end
  end
end
