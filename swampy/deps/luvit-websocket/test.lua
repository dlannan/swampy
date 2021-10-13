local WebSocket = require("../luvit-websocket")

local server = WebSocket.server.new():listen(1337)
print("WebSocket server running on port 1337")

server:on("connect", function(client)
	print("Client connected.")
	client:send("random message")
end)

server:on("data", function(client, message)
	print("New data from client ", client)
	print(message)
	print("Responding by mirroring")
	client:send(message)
end)

server:on("disconnect", function(client)
	print("Client " .. client.id .. " disconnected.")
end)



local http = require('http')

http.createServer(function (req, res)
  local body = "Hello world\n"
  res:setHeader("Content-Type", "text/html")
  res:setHeader("Content-Length", #body)
  res:finish(body)
end):listen(1338)

print('HTTP Server running on port 1338')