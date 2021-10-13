exports.name = "bitmap"
exports.version = "0.0.1"
exports.author = "Niklas Kühtmann"
exports.description = "Utility for working with bitmaps"

local bit = require('bit')

local mt = {}

mt.__index = function(self, k)
    return rawget(self, k) or self.bits[k] or 0
end
mt.__newindex = function(self, k, v)
    if tonumber(k) then
        self:set(k, v)
    else
        rawset(self, k, v)
    end
end

exports.new = function(ta)
    local t={} 
    t.bits = ta or {}

    t.isSet = function(self, index)
        return self.bits[index] == 1
    end

    t.set = function(self, index, value)
        self.bits[index] = value
        return self
    end

    t.toNumber = function(self)
        return tonumber(table.concat(self.bits, ""), 2)
    end

    t.areSet = function(self, ...)
        for k,v in pairs{...} do
            if not self.bits[v] then
                return false
            end
        end
        return true
    end

    t.areNotSet = function(self, ...)
        for k,v in pairs{...} do
            if self.bits[v] then
                return false
            end
        end
        return true
    end

    t.copy = function(self)
        return exports.new(self.bits)
    end

    setmetatable(t, mt)
    return t
end


exports.fromNumber = function(num)
    local t={} 
    while num>0 do
        local rest=math.fmod(num,2)
        t[#t+1]=rest
        num=(num-rest)/2
    end
    return exports.new(t)
end

-- checks for bits being set in value, counted by shift starting at the least significant being 1
exports.isBitSet = function(value, shift)
    shift = shift or 1
    return bit.band(bit.rshift(value, shift-1), 1)
end
