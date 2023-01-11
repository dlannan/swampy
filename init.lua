
package.path = package.path..";./deps/?.lua;./deps/?/init.lua"
package.path = package.path..";./deps/path/?.lua;./deps/stream/?.lua"
package.path = package.path..";./deps/websocket/?.lua"
package.path = package.path..";./deps/tls/?.lua"


---------------------------------------------------------------------------------
-- This was originally for heruko but it doesnt support multi-ports. So.. 
-- local port = 5000
-- local httpsserver = require("app.httpsserver")
-- httpsserver.run(port)

---------------------------------------------------------------------------------

local ffi = require("ffi")

ffi.cdef[[
    int getpid();
    int fork();
    int system( const char *cmd );
]]

---------------------------------------------------------------------------------
local PID           = ffi.C.getpid()
local CHILD_PID     = -1
local port = 5000
---------------------------------------------------------------------------------

-- Dupe the process from here
ffi.C.fork()

-- Check pid 
newPID = ffi.C.getpid()

-- If the router process then...
if(newPID == PID) then
    local router = require("app.router")
    router.run(port)
-- if the Child Webserver process
else 
    CHILD_PID = newPID
    -- Create an internal random port for admin httpserver
    local http_port = port + 50
    local httpsserver   = require("app.httpsserver")
    httpsserver.run(http_port)
end

---------------------------------------------------------------------------------
