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
      @user_identifier = @config.user_identifier
      @daemon_delegate = @config.daemon_delegate.constantize.new
    end

    def start
      puts "[#{Time.now}] daemon started"
      EM.run do
        trap(:INT) do
          EM.stop
          puts "[#{Time.now}] daemon stoped"
        end

        redis = EM::Hiredis.connect
        pubsub = redis.pubsub
        pubsub.subscribe('webrtc-rails')
        pubsub.on(:message) do |channel, message|
          data = JSON.parse(message, {symbolize_names: true})
          user_identifier = data[:user_identifier].to_s
          message = data[:message]
          if @websockets.key?(user_identifier)
            for ws in @websockets[user_identifier]
              send_data = {
                type: 'serverMessage',
                message: message
              }
              ws.send JSON.generate(send_data)
            end
          end
        end
        
        EM::WebSocket.run(host: 'localhost', port: 3001) do |websocket|
          my_user_identifier = nil
          
          websocket.onclose do
            next if my_user_identifier.blank?
            next if @websockets[my_user_identifier].blank?
            @websockets[my_user_identifier].delete(websocket)
            @daemon_delegate.onWebSocketDisconnected(my_user_identifier)
          end

          websocket.onmessage do |message|
            begin
              data = JSON.parse(message, {symbolize_names: true})
              token = data[:token]
              next if token.blank?
              user = @user_class.send(@fetch_user_by_token_method, token.to_s)
              my_user_identifier = user ? user.send(@user_identifier).to_s : nil
              event = data[:event]
              next if my_user_identifier.blank? && event != 'heartbeat'

              case event
              when 'heartbeat'
                user_info = data[:value][:userInfo]
                @daemon_delegate.onWebSocketHeartbeated(my_user_identifier, user_info)
              when 'userMessage'
                user_identifier = data[:value][:userIdentifier]
                event_value = data[:value][:event]
                message = data[:value][:message]
                if @daemon_delegate.onWantSendUserMessage(my_user_identifier, user_identifier, event_value, message)
                  message = {
                    type: 'userMessage',
                    remoteUserIdentifier: my_user_identifier,
                    event: event_value,
                    message: message
                  }
                  sendMessage(user_identifier, message) do
                    message[:type] = 'userMessageFailed'
                    sendMessage(my_user_identifier, message)
                  end
                end
              when 'setMyToken'
                @websockets[my_user_identifier] ||= []
                @websockets[my_user_identifier].push(websocket)
                message = {
                  type: 'myUserIdentifier',
                  myUserIdentifier: my_user_identifier
                }
                @daemon_delegate.onWebSocketConnected(my_user_identifier)
                websocket.send JSON.generate(message)
              when 'sendMessage'
                user_identifier = data[:value][:userIdentifier]
                type = data[:value][:message][:type]
                allow_types = %w/call hangUp offer answer candidate callFailed userMessage webSocketReconnected/
                if @websockets.key?(user_identifier) && type.present? && allow_types.include?(type)
                  if type != 'call' || @daemon_delegate.onWantCall(my_user_identifier, user_identifier)
                    message = data[:value][:message]
                    message[:remoteUserIdentifier] = my_user_identifier
                    sendMessage(user_identifier, message)
                  end
                else
                  message = {
                    type: 'callFailed',
                    reason: 0,
                    remoteUserIdentifier: user_identifier
                  }
                  websocket.send JSON.generate(message)
                end
              end
            rescue => e
              p e
            end
          end
        end
      end
    end

    private

    def sendMessage(user_identifier, message)
      unless @websockets.key?(user_identifier)
        yield if block_given?
        return
      end
      for ws in @websockets[user_identifier]
        ws.send JSON.generate(message)
      end
    end
  end
end
