
-- These are global, but when running in a tee'd vm they will only 
--   be global to the game vm. 

local tcpserve  = require("app.dataserver")
local url       = require("lua.url")
local json      = require("lua.json")
local utils     = require("lua.utils")

-- /data/gettable?name={collection_name}&limit={limit_rows}

api_dataSetTable = function( client, req, res, body )

    local header =  req.headers

    -- Default error
    local outjson = json.encode( { results = nil, status = "Error: Cant set table." } )

    if(header["Name"]) then 

        -- This is effectively the bearertoken for the session. Will be sent with all further requests
        local jsonstr = tcpserve.setTable(header["Name"], body)

        print("[dataSetTable] Name: ", header["Name"])
        outjson = json.encode( { results = {}, status = "OK" } )
    end

    return outjson
end 