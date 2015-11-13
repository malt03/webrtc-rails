require 'rails'

module WebrtcRails
  module Generators
    class UpdateGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      def update_all_files
        js_path = File.join('app', 'assets', 'javascripts')
        template 'main.js.coffee', File.join(js_path, 'webrtc_rails', 'main.js.coffee')
        controller_path = File.join('app', 'controllers')
        template 'webrtc_controller.rb', File.join(controller_path, 'webrtc_controller.rb')
      end

    end
  end
end
