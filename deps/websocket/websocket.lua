
local ffi       = require("ffi")
local wslib     = require("lua.libwebsocket")

ffi.cdef[[
    void memcpy( void *dst, void *src, size_t len );
]]

local clients = {}

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

    local inlen = wslib.WEBSOCKET_get_content( strdata, #data, tmpdata, 4096 )

    if(inlen < 0) then return nil end
    return ffi.string(tmpdata, inlen) 
end

-- ---------------------------------------------------------------------------------

return {
    init        = init,
    free        = free,
    sendframe   = send_frame,
    recvframe   = recv_frame,
}

-- ---------------------------------------------------------------------------------
