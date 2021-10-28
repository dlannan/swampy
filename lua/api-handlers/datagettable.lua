
-- These are global, but when running in a tee'd vm they will only 
--   be global to the game vm. 

local tcpserve  = require("app.dataserver")
local url       = require("lua.url")
local json      = require("lua.json")
local utils     = require("lua.utils")

-- /data/gettable?name={collection_name}&limit={limit_rows}

api_dataGetTable = function( client, req, res )

    local params = url.parse(req.url)
    -- Default error
    local outjson = json.encode( { data = nil, status = "Error: Cant get table." } )

    if(params.query.name and params.query.limit) then 

        -- This is effectively the bearertoken for the session. Will be sent with all further requests
        local jsonstr = tcpserve.getTable(params.query.name, params.query.limit)

        print("[dataGetTable] Name: ", params.query.name, "  Limit: ", params.query.limit)
        outjson = json.encode( { data = jsonstr, status = "OK" } )
    end

    return outjson
end 