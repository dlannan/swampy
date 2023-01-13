
package.path = package.path..";./deps/?.lua;./deps/?/init.lua"
package.path = package.path..";./deps/path/?.lua;./deps/stream/?.lua"
package.path = package.path..";./deps/websocket/?.lua"
package.path = package.path..";./deps/tls/?.lua"

---------------------------------------------------------------------------------
-- Launch router (api connect) and admin web in separate processes. 

---------------------------------------------------------------------------------

local ffi = require("ffi")

ffi.cdef[[
    int getpid();
    int fork();
    int pipe(int *pipes);
]]

---------------------------------------------------------------------------------

local cfg           = require("app.server-config")

---------------------------------------------------------------------------------
local PID           = ffi.C.getpid()
local CHILD_PID     = -1

---------------------------------------------------------------------------------

local pipeFDs = ffi.new("int[2]")

if (ffi.C.pipe( pipeFDs) < 0) then 
    print("[Error] Unable to allocate pipes.")
    return 
end 

-- Dupe the process from here
ffi.C.fork()

-- Check pid 
local newPID = ffi.C.getpid()

-- If the router process then...
if(newPID == PID) then
    local router = require("app.router")
    router.run(cfg.PORT, pipeFDs)
-- if the Child Webserver process
else 
    CHILD_PID = newPID
    -- Create an internal random port for admin httpserver
    local httpsserver   = require("app.httpsserver")
    httpsserver.run(cfg.PORT_WEB, pipeFDs)
end

---------------------------------------------------------------------------------
