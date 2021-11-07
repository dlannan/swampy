local b64   = require( "lua.b64" )

---------------------------------------------------------------------------------
-- Read an entire file.
local function readall(filename)
    local fh = assert(io.open(filename, "rb"))
    local contents = assert(fh:read("a")) -- "a" in Lua 5.3; "*a" in Lua 5.1 and 5.2
    fh:close()
    return contents
end

---------------------------------------------------------------------------------

function string.fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

---------------------------------------------------------------------------------

function string.tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

---------------------------------------------------------------------------------

local function getheader( req, name )

    for k,header in pairs(req.headers) do 
        if(name == header[1]) then return header[2] end 
    end 
    return nil
end

-- ---------------------------------------------------------------------------

local function checklimits( obj, minimum, maximum )
	if( obj > maximum) then obj = minimum end
	if( obj < minimum) then obj = maximum end
	return obj
end

-- ---------------------------------------------------------------------------

local function genname()
	m,c = math.random,("").char 
	name = ((" "):rep(9):gsub(".",function()return c(("aeiouy"):byte(m(1,6)))end):gsub(".-",function()return c(m(97,122))end))
	return(string.sub(name, 1, math.random(4) + 5))
end

-- ---------------------------------------------------------------------------

local function tcount(tbl)
	local cnt = 0
	if(tbl == nil) then return cnt end
	for k,v in pairs(tbl) do 
		cnt = cnt + 1
	end 
	return cnt
end 

---------------------------------------------------------------------------------

local function getcookie( req, cookiename )

    local cvalue = nil
    for k,v in pairs(req.headers) do 
        if(v[1] == "Cookie") then cvalue = v[2]; break end
    end
    
    if(cvalue) then 
        local key, value = string.match(cvalue, "([^=]+)=(.+)")
        if(key == cookiename) then return key, b64.decode(value) end 
    end
    return nil, nil 
end

---------------------------------------------------------------------------------

local function setcookie( res, cookiename, cookievalue )

    local cvalue = b64.encode(cookievalue)
    res:setHeader("Set-Cookie", tostring(cookiename).."="..tostring(cvalue))
end

---------------------------------------------------------------------------------

local function sendjson( res, str )

    res:setHeader("Access-Control-Allow-Origin", "*")
    res:setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    res:setHeader("Access-Control-Allow-Headers", "X-Requested-With,content-type")
    res:setHeader("Access-Control-Allow-Credentials", "true")
    res:setHeader("Content-Type", "application/json")
    res:setHeader("Content-Length", #str)
    res:finish(str)
end 

---------------------------------------------------------------------------------

local function sendhtml( res, str )

    res:setHeader("Access-Control-Allow-Origin", "*")
    res:setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    res:setHeader("Access-Control-Allow-Headers", "X-Requested-With,content-type")
    res:setHeader("Access-Control-Allow-Credentials", "true")
    res:setHeader("Content-Type", "text/html")
    res:setHeader("Content-Length", #str or 0)
    res:finish(str)
end 

---------------------------------------------------------------------------------

local function sendpreflight( res )

    res.statusCode = 200
    res:setHeader("Access-Control-Allow-Origin", "*")
    res:setHeader("Access-Control-Allow-Headers", "Content-Type, Origin, Accept, token, authorization")
    res:setHeader("Access-Control-Allow-Methods", "GET, POST,OPTIONS")
    res:setHeader("Authorization", nil)
    res:finish()
end 

---------------------------------------------------------------------------------

local function senddata( res, data, ctype )

    res:setHeader("Access-Control-Allow-Origin", "*")
    res:setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    res:setHeader("Access-Control-Allow-Headers", "X-Requested-With,content-type")
    res:setHeader("Access-Control-Allow-Credentials", "true")
    res:setHeader("Content-Type", ctype)
    res:setHeader("Content-Length", #data or 0)
    res:finish(data or "")
end 

---------------------------------------------------------------------------------

local function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

---------------------------------------------------------------------------------

local function ls(path)

    local res = ""
    local fh = io.popen("ls -A1 "..path)
    if(fh) then res = fh:read("*a") end 
    return res
end

---------------------------------------------------------------------------------

return {
    ls          = ls, 
    readall     = readall,
    checklimits = checklimits,
    tcount      = tcount,

    genname     = genname,
    split       = split,

    getheader   = getheader,
    getcookie   = getcookie,
    setcookie   = setcookie,
    sendjson    = sendjson,
    sendhtml    = sendhtml,
    senddata    = senddata,
    sendpreflight = sendpreflight,
}

---------------------------------------------------------------------------------
