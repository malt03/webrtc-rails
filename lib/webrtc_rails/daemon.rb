require 'webrtc-rails'
require 'em-websocket'
require 'em-hiredis'

module WebrtcRails
  class Daemon
    def initialize
      @websockets = {}
      @config = WebrtcRails.configuration
      @user_class = @config.user_model_class.constantize
      @fetch_user_by_token_method = @config.fetch_user_by_token_method
      @user_id = @config.user_id
      @daemon_delegate = @config.daemon_delegate.constantize.new
    end

    def start
      EM.run do
        redis = EM::Hiredis.connect
        pubsub = redis.pubsub
        pubsub.subscribe('webrtc-rails')
        pubsub.on(:message) do |channel, message|
          data = JSON.parse(message, {symbolize_names: true})
          user_id = data[:user_id].to_s
          message = data[:message]
          if @websockets.key?(user_id)
            for ws in @websockets[user_id]
              send_data = {
                type: 'serverMessage',
                message: message
              }
              ws.send JSON.generate(send_data)
            end
          end
        end
        
        EM::WebSocket.run(host: 'localhost', port: 3001) do |websocket|
          my_user_id = nil
          
          websocket.onclose do
            if my_user_id.present?
              if @websockets[my_user_id].present?
                @websockets[my_user_id].delete(websocket)
                @daemon_delegate.onWebSocketDisconnected(my_user_id)
              end
            end
          end

          websocket.onmessage do |message|
            data = JSON.parse(message, {symbolize_names: true})
            if data[:event] != 'heartbeat'
              token = data[:token]
              if token.present?
                user = @user_class.send(@fetch_user_by_token_method, token)
                my_user_id = user ? user.send(@user_id).to_s : nil
                if my_user_id.present?
                  case data[:event]
                  when 'userMessage'
                    user_id = data[:value][:userID]
                    event = data[:value][:event]
                    message = data[:value][:message]
                    if @daemon_delegate.onWantSendUserMessage(my_user_id, user_id, event, message)
                      message = {
                        type: 'userMessage',
                        remoteUserID: my_user_id,
                        event: event,
                        message: message
                      }
                      sendMessage(user_id, message)
                    end
                  when 'setMyToken'
                    @websockets[my_user_id] ||= []
                    @websockets[my_user_id].push(websocket)
                    message = {
                      type: 'myUserID',
                      myUserID: my_user_id
                    }
                    @daemon_delegate.onWebSocketConnected(my_user_id)
                    websocket.send JSON.generate(message)
                  when 'sendMessage'
                    user_id = data[:value][:userID]
                    type = data[:value][:message][:type]
                    allow_types = %w/call hangUp offer answer candidate callFailed userMessage webSocketReconnected/
                    if @websockets.key?(user_id) && type.present? && allow_types.include?(type)
                      if type != 'call' || @daemon_delegate.onWantCall(my_user_id, user_id)
                        message = data[:value][:message]
                        message[:remoteUserID] = my_user_id
                        sendMessage(user_id, message)
                      end
                    else
                      message = {
                        type: 'callFailed',
                        reason: 0,
                        remoteUserID: user_id
                      }
                      websocket.send JSON.generate(message)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    private

    def sendMessage(user_id, message)
      for ws in @websockets[user_id]
        ws.send JSON.generate(message)
      end
    end
  end
end
