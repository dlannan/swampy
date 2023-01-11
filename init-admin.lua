
package.path = package.path..";./deps/?.lua;./deps/?/init.lua"
package.path = package.path..";./deps/path/?.lua;./deps/stream/?.lua"
package.path = package.path..";./deps/websocket/?.lua"
package.path = package.path..";./deps/tls/?.lua"

---------------------------------------------------------------------------------
-- This was originally for heruko but it doesnt support multi-ports. So.. 
-- local port = 5000
-- local httpsserver = require("app.httpsserver")
-- httpsserver.run(port)

local port = 5050
local httpsserver = require("app.httpsserver")
httpsserver.run(port)
