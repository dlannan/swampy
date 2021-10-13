exports.name = "WebSocket Server"
exports.version = "0.0.1"

local net = require("net")
local wsu = require("websocketutils")
local table = require("table")

exports.new = function(func)
	local t = {}

	t.listener = {connect = {}, data = {}, disconnect = {}, timeout = {}}
	t.clients = {}

	t.on = function(self, s, c)
		if self.listener[s] and type(self.listener[s]) == "table" and type(c) == "function" then
			table.insert(self.listener[s], c)
		end
		return self
	end

	t.call = function(self, s, ...)
	    if self.listener[s] and type(self.listener[s]) == "table" then
	    	local t = {}
	      	for k,v in pairs(self.listener[s]) do
	        	if type(v) == "function" then
	        		local r = v(...)
	        		if r then
            			table.insert(t, r)
	        		end
	        	end
	      	end
	      	return unpack(t)
	    end
	end

	t.server = net.createServer(function(client)
		client.oldBuffer = ""

		client:on("data", function(c)
			client.send = function(self, msg)
				client:write(wsu.assemblePacket(msg))
			end

			if c:sub(1,3) == "GET" then 
				client:write(wsu.assembleHandshakeResponse(c))
				t:call("connect", client)

		        table.insert(t.clients, client)
		        for k,v in pairs(t.clients) do
		          if v == client then
		            client.id = k
		          end
		        end
			else
				local message, v = wsu.disassemblePacket(client.oldBuffer .. c)
				if message == 3 then
					client.oldBuffer = client.oldBuffer .. c
				elseif message == 2 then
					t:call("disconnect", client)
					t.clients[client.id or 0] = nil
				elseif message == 1 then
					client:write(v)
					client.oldBuffer = ""
				elseif message then
					t:call("data", client, message)
					client.oldBuffer = ""
				else 
					print("WebSocket Error: Could not parse message.")
				end
			end
		end)

		local function onTimeout()
			print("Timeout")
			t:call("timeout", client)
			t.clients[client.id or 0] = nil
  			client:_end()
		end
		client:once('timeout', onTimeout)
		process:once('exit', onTimeout)
		client:setTimeout(1800000)

		client:on('end', function()
			t:call("disconnect", client)
			t.clients[client.id or 0] = nil
    		process:removeListener('exit', onTimeout)
		end)

	end)

	t.listen = function(self, ...)
		t.server:listen(...)
		return self
	end

	if type(func) == "function" then
		func(t)
	end

	return t
end

return exports