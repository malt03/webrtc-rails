require 'rails'

module WebrtcRails
  module Generators
    class InstallGenerator < Rails::Generators::Base
      def injection_js
        append_to_file File.join(js_path, 'application.js') do
          out = ''
          out << "\n\n// append by webrtc_rails\n"
          out << "//= require webrtc_rails/main\n\n"
        end
      end
    end
  end
end
