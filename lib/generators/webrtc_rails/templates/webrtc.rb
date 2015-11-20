#!/usr/bin/env ruby

ENV["RAILS_ENV"] ||= "production"

root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

@websockets = {}

EM.run do
  EM::WebSocket.run(host: 'localhost', port: 3001) do |websocket|
    my_user_id = nil
    
    websocket.onclose do
      if my_user_id.present?
        if @websockets[my_user_id].present?
          @websockets[my_user_id].delete(websocket)
        end
      end
    end

    websocket.onmessage do |message|
      data = JSON.parse(message, {symbolize_names: true})
      if data[:event] != 'heartbeat'
        token = data[:token]
        if token.present?
          user = User.fetch_by_token(token)
          my_user_id = user ? user.id.to_s : nil
          if my_user_id.present?
            case data[:event]
            when 'setMyToken'
              @websockets[my_user_id] ||= []
              @websockets[my_user_id].push(websocket)
              message = {
                type: 'myUserID',
                myUserID: my_user_id
              }
              websocket.send JSON.generate(message)
            when 'sendMessage'
              user_id = data[:value][:userID]
              type = data[:value][:message][:type]
              Rails.logger.info type
              allow_types = %w/call hangUp offer answer candidate callFailed webSocketReconnected/
              if @websockets.key?(user_id) && type.present? && allow_types.include?(type)
                for ws in @websockets[user_id]
                  message = data[:value][:message]
                  message[:remoteUserID] = my_user_id
                  ws.send JSON.generate(message)
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
