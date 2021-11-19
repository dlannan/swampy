local net = require('net')

local ws_server = {}
local default_callbacks = {}

default_callbacks.onerror = function(client, error) 
    local source = "Client"
    if(client == nil) then source = "Server" end
    print("[WebSocket] "..source.." Error: "..tostring(error))
end

default_callbacks.onmessage = function(client, data) 
    print("[WebSocket] Data: "..tostring(data))
end

default_callbacks.onclose = function(client) 
    print("[WebSocket] Close")
end

local function createServer( callbacks )

    local server = net.createServer(function(client)
        print("Client connected")

        -- Add some listenners for incoming connection
        client:on("error",function(err)
            print("Client read error: " .. err)
            if(callbacks.onerror) then callbacks.onerror(client, err) end
            client:close()
        end)

        client:on("data",function(data)
            if(callbacks.onmessage) then callbacks.onmessage(client, data) end
            -- client:write(data)
        end)

        client:on("end",function()
            print("Client disconnected")
            if(callbacks.onclose) then callbacks.onclose(client) end
        end)
    end)

    -- Add error listenner for server
    server:on('error',function(err)
        if err then error(err) end
        if(callbacks.onerror) then callbacks.onerror(nil, err) end
    end) 

    return server
end

ws_server.init = function( callbacks )

    callbacks = callbacks or default_callbacks
    return createServer(callbacks)
end 

ws_server.bind = function( server, port, host )
    
    server:listen(port, host) 
end 

ws_server.send_text = function( client, data )

    client:write(data) 
end

return ws_server