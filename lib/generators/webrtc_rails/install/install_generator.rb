require 'rails'

module WebrtcRails
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../templates", __FILE__)

      def create_initializer_file
        initializer_path = File.join('config', 'initializers')
        file_name = webrtc_rails.rb
        template file_name, File.join(initializer_path, file_name)
      end
      
      def injection_js
        append_to_file File.join(js_path, 'application.js') do
          out = ''
          out << "\n\n// append by webrtc_rails\n"
          out << "//= require app/webrtc_rails/main\n\n"
        end
      end
    end
  end
end
