local exports = {}

exports.name = "websocketutils"
exports.version = "0.0.1"
exports.author = "Niklas Kühtmann"

local bitmap = require('bitmap')
local bit = require('bit')
local bytemap = require('bytemap')
local b64 = require("base64")
local sha1 = require("sha1")
local string = require("string")

local ffi = require("ffi")

-- The Websocket data frame layout
-- 0                   1                   2                   3
-- 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
-- +-+-+-+-+-------+-+-------------+-------------------------------+
-- |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
-- |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
-- |N|V|V|V|       |S|             |   (if payload len==126/127)   |
-- | |1|2|3|       |K|             |                               |
-- +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
-- |     Extended payload length continued, if payload len == 127  |
-- + - - - - - - - - - - - - - - - +-------------------------------+
-- |                               |Masking-key, if MASK set to 1  |
-- +-------------------------------+-------------------------------+
-- | Masking-key (continued)       |          Payload Data         |
-- +-------------------------------- - - - - - - - - - - - - - - - +
-- :                     Payload Data continued ...                :
-- + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
-- |                     Payload Data continued ...                |
-- +---------------------------------------------------------------+


string.split = function(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end

    local t={}
    local i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

exports.disassemblePacket = function(buffer)
    local bytemap = bytemap.fromString(buffer)

    -- flag evaluation
    local bitmap = bitmap.fromNumber(bytemap[1])

    local fin = bitmap:isSet(1);
    local rsv1 = bitmap:isSet(2); rsv2 = bitmap:isSet(3); rsv3 = bitmap:isSet(4)
    local opcode = tonumber(bitmap[5] .. bitmap[6] .. bitmap[7] .. bitmap[8], 2)

    local frag = nil 
    --print(fin, rsv1, rsv2, rsv3, opcode)

    -- message fragmentation check
    -- Fragmentation start
    if fin == false and opcode > 0 then
        --print("[FRAG START]", opcode)
        frag = true
    end
    -- Fragmentation segment
    if fin == false and opcode == 0 then
        --print("[FRAG FRAME]", opcode)
        frag = true
    end
    if fin == true and opcode == 0 then
        --print("[FRAG FINISH]", opcode)
        frag = nil
    end

    -- client request close
    if opcode == 8 then
        return 2
    end

    -- ping - pong
    if opcode == 9 then
        bitmap[8] = true
        bitmap[7] = false
        bytemap[1] = bitmap:toNumber()
        return 1, bytemap:toString()
    end

    -- remove flags from bytemap
    bytemap:popStart()

    -- get packet size (needed for message fragmentation later on, sits inbetween so get it, why not)
    -- need to know where to cut off anyway
    local length = bytemap[1] - 128
    bytemap:popStart()
    if length == 126 then
        length = bytemap:toNumber(1,2)
        bytemap:popStart(2)
    elseif length == 127 then
        length = bytemap:toNumber(1,2,3,4,5,6,7,8)
        bytemap:popStart(8)
    end    

    -- get mask
    local mask = {bytemap:get(1,2,3,4)}

    -- remove mask from bytemap
    bytemap:popStart(4)

    -- check if the tcp handler missed to push something
    if length > #bytemap.bytes then
        return 3
    end

    -- finally decode and return
    local ret = ""
    bytemap:forEach(function(k,v)
        local i = k % 4
        ret = ret .. string.char(bit.bxor(mask[i > 0 and i or 4], v))
    end)

    return ret, frag
end

exports.assemblePacket = function(buffer)
    local flags = "10000001"
    local bmap = bytemap.new({tonumber(flags, 2), #buffer})
    
    if bmap[2] >= 65536 then
        local length = bmap[2]
        for i = 10, 3, -1 do
            bmap[i] = bit.band(length, 0xFF)
            length = bit.rshift(length, 8)
        end
        bmap[2] = 127
    elseif bmap[2] >= 126 then
        bmap[4] = bit.band(bmap[2], 0xFF)
        bmap[3] = bit.band(bit.rshift(bmap[2], 8), 0xFF)
        bmap[2] = 126
    end
    for i = 1, #buffer do
        bmap:push(string.byte(buffer:sub(i, i)))
    end

    local ret = ""
    bmap:forEach(function(k,v)
        ret = ret .. string.char(v)
    end)

    return ret
end

exports.assembleHandshakeResponse = function(handshake)
    local lines = handshake:split('\r\n')
    local title = lines[1]
    lines[1] = nil
    local data = {}

    for k,v in pairs(lines) do
      if #v > 2 then
        local line = v:split(": ")
        data[line[1]] = line[2]
      end
    end

    local responseKey = data["Sec-WebSocket-Key"] .. '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
    responseKey = b64.encode(sha1.binary(responseKey))
    
    return  "HTTP/1.1 101 Switching Protocols\r\n"
          .."Connection: Upgrade\r\n"
          .."Upgrade: websocket\r\n"
          .."Sec-WebSocket-Accept: " .. responseKey .. "\r\n"
          .."\r\n"
end

return exports