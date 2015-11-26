require 'webrtc_rails'

namespace :webrtc_rails do
  desc 'start webrtc daemon'
  task :start do
    WebrtcRails::Daemon.start
  end
end
