exports.name = "bytemap"
exports.version = "0.0.1"
exports.author = "Niklas Kühtmann"
exports.description = "Utility for working with bytemaps"

local string = require('string')
local table = require('table')
local mt = {}

mt.__index = function(self, k)
    return rawget(self, k) or self.bytes[k]
end
mt.__newindex = function(self, k, v)
    if tonumber(k) and tonumber(v) then
        self.bytes[k] = v
    else
        rawset(self, k, v)
    end
end

exports.new = function(ta)
    local t = {}
    t.bytes = ta or {}

    t.split = function(self, amt)
        if amt < 0 then
            amt = table.getn(self.bytes) - ((amt >= 0) and amt or (amt * -1))
        end

        local t = {}

        for k,v in pairs(self.bytes) do
            if k > amt then
                table.insert(t, v)
                self.bytes[k] = nil
            end
        end

        return self, exports.new(t)
    end 
    t.cut = function(self, amt)
        if amt < 0 then
            amt = table.getn(self.bytes) - ((amt >= 0) and amt or (amt * -1))
        end

        local t = {}

        for k,v in pairs(self.bytes) do
            if k > amt then
                t[k] = v
                self.bytes[k] = nil
            end
        end

        return self, exports.new(t)
    end
    t.popStart = function(self, reps)
        local ret = {}
        reps = reps or 1
        for i = 1, reps do
            local v,t = self:split(1)
            self.bytes = t.bytes
            table.insert(ret, v.bytes[1])
        end
        return unpack(ret)
    end
    t.popEnd = function(self)
        local _,v = self:split(-1)
        return v.bytes[1]
    end
    t.toString = function(self)
        local s = ""
        for k,v in pairs(self) do
            s = s .. string.char(v)
        end
        return s
    end
    t.toNumber = function(self, ...)
        local vargs = {...}
        local t = {}
        local c = #vargs
        if c == 0 then
            t = self.bytes
            c = #t
        else
            for k,v in pairs(vargs) do
                table.insert(t, self.bytes[v])
            end
        end
        local hex = ""
        for i = 1, c do
            hex = hex .. "%x"
        end
        return tonumber(string.format(hex, unpack(t)), 16)
    end
    t.get = function(self, ...)
        local t = {}
        for k,v in pairs({...}) do
            table.insert(t, self.bytes[k])
        end
        return unpack(t)
    end
    t.push = function(self,v)
        table.insert(self.bytes, v)
        return self
    end
    t.forEach = function(self, f)
        local t = {}
        for k,v in pairs(self.bytes) do
            local r = f(k,v)
            if r then
                table.insert(t, r)
            end
        end
        return t
    end

    t.copy = function(self)
        return exports.new(self.bytes)
    end

    setmetatable(t, mt)
    return t
end



exports.fromString = function(str)
    local t = {}
    for i = 1, #str do
        t[i] = string.byte(str:sub(i,i))
    end
    return exports.new(t)
end