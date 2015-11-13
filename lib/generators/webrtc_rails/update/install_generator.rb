require 'rails'

module WebrtcRails
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      def create_events_initializer_file
        js_path = File.join('app', 'assets', 'javascripts')
        template 'main.js.coffee', File.join(js_path, 'webrtc_rails', 'main.js.coffee')
        append_to_file File.join(js_path, 'application.js') do
          out = ''
          out << "\n\n// append by webrtc_rails\n"
          out << "//= require webrtc_rails/main\n\n"
        end
      end

      def create_webrtc_controller
        controller_path = File.join('app', 'controllers')
        template 'webrtc_controller.rb', File.join(controller_path, 'webrtc_controller.rb')
      end

      def add_route
        route "post '/webrtc', :to => 'webrtc#send_message'"
      end
    end
  end
end
