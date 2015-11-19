require 'rails'

module WebrtcRails
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      def generate_daemon
        daemons_dir = Daemons::Rails.configuration.daemons_directory
        unless File.exists?(Rails.root.join(daemons_dir, 'daemons'))
          copy_file "daemons", daemons_dir.join('daemons')
          chmod daemons_dir.join('daemons'), 0755
        end

        script_path = daemons_dir.join('webrtc.rb')
        template 'webrtc.rb', script_path
        chmod script_path 0755

        ctl_path = daemons_dir.join('webrtc_ctl')
        template "webrtc_ctl", ctl_path
        chmod ctl_path, 0755

        unless File.exists?(Rails.root.join('config', 'daemons.yml'))
          copy_file 'daemons.yml', 'config/daemons.yml'
        end
      end

      def create_events_initializer_file
        js_path = File.join('app', 'assets', 'javascripts')
        template 'main.js.coffee', File.join(js_path, 'webrtc_rails', 'main.js.coffee')
        append_to_file File.join(js_path, 'application.js') do
          out = ''
          out << "\n\n// append by webrtc_rails\n"
          out << "//= require webrtc_rails/main\n\n"
        end
      end
    end
  end
end
