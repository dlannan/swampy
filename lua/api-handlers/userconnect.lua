
-- These are global, but when running in a tee'd vm they will only 
--   be global to the game vm. 

local tcpserve  = require("app.dataserver")
local url       = require("lua.url")
local json      = require("lua.json")
local aes       = require("lua.aes")
local utils     = require("lua.utils")

-- User login generates a bearer token - connect then associates username with device_id and bearer token
-- The bearer token is set in the http header when other requests are made.
-- /user/connect?module={game_module}&name={playername}&uid={device_uid}

api_userConnect = function( client, req, res )

    local header =  req.headers
    -- Default error
    local outjson = json.encode( { data = nil, status = "Error: No connect" } )

    local btoken = utils.getheader(req, "Authorization")
    local isok = tcpserve.checkToken(btoken)

    -- Get module, name and device must be present - if device changes, then no connect, need login
    if(header["Module"] and header["Name"] and header["DeviceId"] and isok) then

        -- Looks up in db and returns the bearertoken generated during login
        local userinfo = tcpserve.connectUser(client, header["Module"], header["Name"], header["DeviceId"])

        if(userinfo) then 

            print("[userConnect] Name: ", header["Name"], "  Device: ",header["DeviceId"])
            outjson = json.encode( { data = userinfo, status = "OK" } )
        else
            outjson = json.encode( { data = nil, status = "Error: User cant connect" } )
        end
    end

    return outjson 
end 