local b64   = require("lua.b64")
local sha1  = require("sha1")
local utils = require("lua.utils")
local ffi   = require("ffi")
local wslib = require("websocket.websocket")

-- Websocket frame structure:
--   https://datatracker.ietf.org/doc/html/rfc6455#section-5.2
--
--     0                   1                   2                   3
--     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
--    +-+-+-+-+-------+-+-------------+-------------------------------+
--    |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
--    |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
--    |N|V|V|V|       |S|             |   (if payload len==126/127)   |
--    | |1|2|3|       |K|             |                               |
--    +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
--    |     Extended payload length continued, if payload len == 127  |
--    + - - - - - - - - - - - - - - - +-------------------------------+
--    |                               |Masking-key, if MASK set to 1  |
--    +-------------------------------+-------------------------------+
--    | Masking-key (continued)       |          Payload Data         |
--    +-------------------------------- - - - - - - - - - - - - - - - +
--    :                     Payload Data continued ...                :
--    + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
--    |                     Payload Data continued ...                |
--    +---------------------------------------------------------------+

local buffers = {}

-- ---------------------------------------------------------------------------------

local function webDataSend( data )

    --print("[WS SEND] ", data)
    local encdata = webSocketEncode(data) 
    return encdata
end

-- ---------------------------------------------------------------------------------

local function webDataWrite(client, data )

    wslib.sendframe(client, data )
end 

-- ---------------------------------------------------------------------------------

local function webSocketHandshake( client, data )

    wslib.handshake( client, data )
end

-- ---------------------------------------------------------------------------------

local function checkHandshake( t, client )

    -- Check if data has a \r\n\r\n on the end 
    local buffertail = string.sub(client.ws_buffer, -4, -1)
    if( buffertail == "\r\n\r\n" ) then 

        -- Send handshake response
        webSocketHandshake( client, client.ws_buffer )
        t:call("onopen", client)

        table.insert(t.clients, client)
        -- Check for existing clients
        for k,v in pairs(t.clients) do
            if v == client then
                client.id = k
            end
        end

        client.mode = "websocket"
        client.ws_buffer = ""
    end 
end

-- ---------------------------------------------------------------------------------

local function processStart( t, client, data )

    -- Check for initiation of websocket 
    if(string.sub(data, 1,3 ) == "GET") then 
        client.mode = "handshake"
        client.ws_buffer = data 
        checkHandshake(t, client)
    end 
end 

-- ---------------------------------------------------------------------------------

local function processHandShake( t, client, data )

    client.ws_buffer = client.ws_buffer..data
    checkHandshake( t, client )
end

-- ---------------------------------------------------------------------------------

local function processWebSocket( t, client, data )

    -- We dont allow more than 1K packets. That coul;d be configurable if needed
    if(#client.ws_buffer > 1024) then client.ws_buffer = "" end 
    if(data) then client.ws_buffer = client.ws_buffer..data end

    local msg, state = wslib.recvframe( client, client.ws_buffer )
    --p(#data, #msg, state)

    -- Something went wrong - close, or an unknown error - reset things
    if(msg == nil) then 

        t:call("onclose", client)
        client.ws_buffer   = ""
        client.mode     = nil
        t.clients[client.id or 0] = nil

    -- A Ping was requested by client, we send a Pong
    elseif(state.opcode == 9) then 
    
        client:write(msg or "")
        client.ws_buffer   = ""

    -- A close was requested from client
    elseif(state.opcode == 8) then 

        t:call("onclose", client)
        client.ws_buffer   = ""
        client.mode     = nil
        t.clients[client.id or 0] = nil

    -- Check the processed data matches the packet_length returned
    elseif( state.packet_length <= #msg ) then 

    -- Determine fragmented frames and handle differently
    -- fragmented = state
    -- if(state.fin == 1 and state.opcode ~= 0) then 
    --     fragmented = nil
    -- end

    -- Deal with fragmented frames - coalesce them together into the client buffer
    -- if(fragmented) then 
    --     client.mode = "fragmented"
    --     client.ws_buffer = client.ws_buffer..(msg or "")
    -- else 
    
        -- If the data is ok to send to user then..
        if(state.opcode == 1 or state.opcode == 2) then
            if(state.fin == 1) then 
                t:call("onmessage", client, msg)
                client.ws_buffer = ""
            end
        end
    end 
end

-- ---------------------------------------------------------------------------------

local function processFragment( t, client, data )

    local msg, state = wslib.recvframe( client, data )
    --p('[WS DATA] ', data, state)
    if(msg == nil) then 
        client.mode = "websocket"
    else 

        if( state.fin == 0 and state.opcode ~= 0 ) then 

            client.ws_buffer = client.ws_buffer..msg
        elseif( state.fin == 0 and state.opcode == 0 ) then 

            client.ws_buffer = client.ws_buffer..msg
        -- Fragment complete
        elseif( state.fin == 1 and state.opcode == 0 ) then

            client.ws_buffer = client.ws_buffer..msg
            t:call("onmessage", client, client.ws_buffer)
            client.ws_buffer = ""
            client.mode = "websocket"
        end 
    end
end

-- ---------------------------------------------------------------------------------

local function webDataProcess( t, client, data )

    if(client.id == nil) then client.id = math.floor(os.clock() * 10000) end

    -- Quickly determine course of action
    -- 1. is this handshake data - wait until end
    -- 2. is this a frame - collect data (until next valid frame) 
    -- 3. is this data (frame or handshake) add to buffer

    if(client.mode == nil) then 

        processStart( t, client, data )
    elseif(client.mode == "handshake") then 

        processHandShake( t, client, data )
    elseif(client.mode == "websocket") then

        processWebSocket( t, client, data )
    elseif(client.mode == "fragment") then 

        processFragment( t, client, data )
    end 
end 

-- ---------------------------------------------------------------------------------

return {

    webDataSend         = webDataSend,
    webDataWrite        = webDataWrite,
    webDataProcess      = webDataProcess,
}

-- ---------------------------------------------------------------------------------
