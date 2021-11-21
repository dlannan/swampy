
local ffi       = require("ffi")
local wslib     = require("lua.libwebsocket")

ffi.cdef[[
    void memcpy( void *dst, void *src, size_t len );
]]

local clients = {}

-- ---------------------------------------------------------------------------------

local function hand_shake( data )

    local strdata = ffi.new("unsigned char[?]", #data)
    ffi.copy(strdata, ffi.string(data, #data), #data)
    local tmpdata = ffi.new("char[4096]")

    local dlen = wslib.WEBSOCKET_generate_handshake( data, tmpdata, 4096 )
    local retstr = ffi.string(tmpdata, dlen)
    return tostring(retstr)
end

-- ---------------------------------------------------------------------------------

local function send_frame( client, data )
   
    local strdata = ffi.new("unsigned char[?]", #data)
    ffi.copy(strdata, ffi.string(data, #data), #data)
    local tmpdata = ffi.new("char[4096]")

    local outlen = wslib.WEBSOCKET_set_content( strdata, #data, tmpdata, 4096 )
    local outdata = ffi.string(tmpdata, outlen)

    client:write(outdata)
end

-- ---------------------------------------------------------------------------------

local function recv_frame( client, data )

    local strdata = ffi.new("char[?]", #data)
    ffi.copy(strdata, ffi.string(data, #data), #data)
    local tmpdata = ffi.new("unsigned char[4096]")
    ffi.fill( tmpdata, 4096 )
    local hdr = ffi.new("unsigned char[2]")
    local inlen = wslib.WEBSOCKET_get_content( strdata, #data, tmpdata, 4096, hdr )

    local state = {
        fin     = bit.band(bit.rshift(hdr[0], 7), 1), 
        opcode  = bit.band(hdr[0], 0x0F),
        resv    = bit.band(bit.rshift(hdr[0], 4), 7),
        mask    = bit.rshift(hdr[1], 7),
        packet_length = inlen,
    }

    if(inlen < 0) then return nil, state end
    local msg = ffi.string(tmpdata)
    return tostring(msg), state  
end

-- ---------------------------------------------------------------------------------

return {
    init        = init,
    free        = free,
    sendframe   = send_frame,
    recvframe   = recv_frame,
    handshake   = hand_shake, 
}

-- ---------------------------------------------------------------------------------
