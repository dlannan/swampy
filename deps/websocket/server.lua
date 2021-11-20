local net = require('net')
local tls = require('tls')
local handler = require('websocket.handler')

local default_options   = {

}

local default_callbacks = {

    onerror = {
        function(client, error) 
            local source = "Client"
            if(client == nil) then source = "Server" end
            print("[WebSocket] "..source.." Error: "..tostring(error))
        end
    },

    onopen = {
        function(client) 
            print("[WebSocket] Open ")
        end
    },

    onmessage = {
        function(client, data) 
            print("[WebSocket] Data: "..tostring(data))
        end
    },

    onclose = { 
        function(client) 
            print("[WebSocket] Close")
        end
    },

    ontimeout = {
        function(client)
            print("[WebSocket] Timeout")
        end
    },
}

local empty_callbacks = {
    onerror     = {},
    onopen      = {},
    onmessage   = {},
    onclose     = {},
    ontimeout   = {},
}

local function createServer( options, func )

    options = options or default_options

    local t = {}
    t.listener  = empty_callbacks
	t.clients   = {}

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

    t.server = net.createServer(options, function(client)

        -- Add some listenners for incoming connection
        client:on("error",function(err)
            print("Client read error: ")
            p(err)
			client.mode = nil
            t:call("onopen", client)
            client:close()
        end)

        client:on("data",function(data)

			client.send = function(self, data)
				handler.webDataWrite(client, data)
			end
            
            handler.webDataProcess(t, client, data)
            -- client:write(data)
        end)

		local function onTimeout()
			print("Timeout")
			t:call("ontimeout", client)
			t.clients[client.id or 0] = nil
  			client:_end()
		end

        client:once('timeout', onTimeout)
		process:once('exit', onTimeout)
		client:setTimeout(1800000)

        client:on("end",function()
            client.mode = nil

			t:call("onclose", client)
            print("Client disconnected")
			t.clients[client.id or 0] = nil
    		process:removeListener('exit', onTimeout)
        end)
    end)

    -- Add error listenner for server
    t.server:on('error',function(err)
        if err then error(err) end
        if(t.listener.onerror) then t.listener.onerror(nil, err) end
    end) 

	t.listen = function(self, ...)
		t.server:listen(...)
		return self
	end

    -- Callback after setup
	if type(func) == "function" then
		func(t)
	end

    return t
end

return {
    create      = createServer,
}