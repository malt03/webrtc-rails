require 'redis'
require 'json'

module WebrtcRails
  module ServerMessage
    def send(user_identifier, message)
      data = {
        user_identifier: user_identifier,
        message: message,
      }
      redis = Redis.new
      redis.publish('webrtc-rails', JSON.generate(data))
    end

    module_function :send
  end
end
