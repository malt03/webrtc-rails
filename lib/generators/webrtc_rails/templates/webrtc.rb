#!/usr/bin/env ruby

ENV["RAILS_ENV"] ||= "production"

root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

@webSockets = {}

EM.run do
  EM::WebSocket.run(host: 'localhost', port: 3001) do |webSocket|
    myIdentifier = nil
    
    webSocket.onclose do
      if myIdentifier
        @webSockets[myIdentifier].delete(webSocket)
      end
    end

    webSocket.onmessage do |message|
      data = JSON.parse(message, {symbolize_names: true})
      case data[:event]
      when 'setMyIdentifier'
        identifier = data[:value][:identifier]
        myIdentifier = identifier
        @webSockets[identifier] ||= []
        @webSockets[identifier].push(webSocket)
      when 'sendMessage'
        identifier = data[:value][:identifier]
        if @webSockets[identifier]
          for ws in @webSockets[identifier]
            ws.send JSON.generate(data[:value][:message])
          end
        end
      end
    end
  end
end
