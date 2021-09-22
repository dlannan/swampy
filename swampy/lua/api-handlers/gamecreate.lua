
-- These are global, but when running in a tee'd vm they will only 
--   be global to the game vm. 

local tcpserve  = require("app.dataserver")
local url       = require("lua.url")
local json      = require("lua.json")
local utils     = require("lua.utils")

-- /game/create?name={game_name}&uid={user_id}

api_gameCreate = function( client, req, res )

    local params = url.parse(req.url)
    -- Default error
    local outjson = json.encode( { result = nil, status = "Error: Cant create game." } )

    if(params.query.name and params.query.uid) then 

        -- This is effectively the bearertoken for the session. Will be sent with all further requests
        local jsonstr = tcpserve.gameCreate(params.query.uid, params.query.name)

        print("[gameCreate] Name: ", params.query.name, "  UID: ", params.query.uid)
        outjson = json.encode( { result = jsonstr, status = "OK" } )
    end

    return outjson
end 