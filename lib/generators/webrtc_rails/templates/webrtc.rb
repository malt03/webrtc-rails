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
      if my_user_id
        @websockets[my_user_id].delete(websocket)
      end
    end

    websocket.onmessage do |message|
      data = JSON.parse(message, {symbolize_names: true})
      case data[:event]
      when 'setMyToken'
        token = data[:value][:token]
        if token.present?
          my_user_id = User.fetch_by_token(token).id.to_s
          if my_user_id.present?
            @websockets[my_user_id] ||= []
            @websockets[my_user_id].push(websocket)
            message = {
              type: 'myUserID',
              myUserID: my_user_id
            }
            websocket.send JSON.generate(message)
          end
        end
      when 'sendMessage'
        user_id = data[:value][:userID]
        type = data[:value][:message][:type]
        allow_types = %w/call hangUp hangUpAnswer offer answer candidate/
        if @websockets.key?(user_id) && type.present? && allow_types.include?(type)
          for ws in @websockets[user_id]
            ws.send JSON.generate(data[:value][:message])
          end
        else
          message = { type: 'callFailed' }
          websocket.send JSON.generate(message)
        end
      end
    end
  end
end
