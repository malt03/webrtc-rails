require 'redis'
require 'json'

module WebrtcRails
  module ServerMessage
    def send(user_id, message)
      data = {
        user_id: user_id,
        message: message,
      }
      redis = Redis.new
      redis.publish('webrtc-rails', JSON.generate(data))
    end

    module_function :send
  end
end
