---------------------------------------------------------------------------------

local tinsert   = table.insert

local json      = require "lua.json"
local api       = require "lua.module-api"

local rounds    = require "lua.modules.soulsurvivor.soulsurvivor-rounds"

local sqlapi    = require "lua.sqlapi"
local games     = require "app.gameserver"

---------------------------------------------------------------------------------
-- A name for the game. 
local modulename        = "SoulSurvivor"

---------------------------------------------------------------------------------
-- Update this module with info about numebr of games, users and activity
-- Go through games and update their states
-- 

local MODULEDB_FILE     = "soulsurvivor"
local MAXIMUM_GAMESIZE  = 10
local USER_TIMEOUT      = 10       -- Ten seconds timeout (default is 120)

local SERVER_FILE       = "./data/ss.sqlite3"

local SQLITE_TABLES = {
    ["persons"]      = { create = "desc TEXT, theme TEXT" },
    ["traits"]       = { create = "desc TEXT, theme TEXT" },
    ["scenarios"]    = { create = "desc TEXT, theme TEXT" },
}

---------------------------------------------------------------------------------

local soulsurvivor = {

    USER_TIMEOUT    = 120,      
    name            = modulename,      
    
    sqltables       = SQLITE_TABLES,

    USER_TIMEOUT    = USER_TIMEOUT,
    max_games       = 50,
}

---------------------------------------------------------------------------------
-- A sql db is used for the game module. 

local function initModule(mod)

    if(args[2] == "rebuild") then 

        mod.sql.prevconn = sqlapi.getConn()
        sqlapi.setConn(mod.sql.conn)

        -- First drop any tables that are named same. 
        for k,v in pairs(mod.sqltables) do
            sqlapi.dropTable( k )
        end 

        p("Removing old sqldb.")
        os.execute("rm "..MODULEDB_FILE)
    
        sqlapi.checkTables(mod.sqltables)

        p("Importing sqldb.")
        sqlapi.importJSONFile( "./data/soulsurvivor-import.json" )
        
        -- restore sql conn
        sqlapi.setConn(mod.sql.prevconn)
    end
end 

---------------------------------------------------------------------------------

local function createGameState( game )

    rounds.setup( soulsurvivor, game )
end 

---------------------------------------------------------------------------------
-- Example update slot
-- {
--      uid - user who sent this update 
--      timestamp - used to sort order the updates
--      playerstate - json text of events
--      metadata - json data to be used across updates
-- }

local function getPlayerData( game )

    -- Dont process if its not ready yet 
    if(game.updates == nil) then return end 

    -- player data should be all in the game->update table. 
    --    Each update with a timestamp, and player update details in it.

    -- sort ascending by timestamp
    table.sort(game.updates, function(a,b) return a.timestamp < b.timestamp end)
    for k,v in ipairs(game.updates) do 

    end 
end 

---------------------------------------------------------------------------------

local function moduleError( error )

    p(error)
end 

---------------------------------------------------------------------------------

local function applyGameInputs( game )


end 

---------------------------------------------------------------------------------

local function updateGameState( game, frame, dt )

    -- fetch from sqltable. That is the "master" state
    -- Update every 500 ms - that should be plenty for this type of game
    if(soulsurvivor.info.lastupdate <= 0.0) then 

        local playerdata = getPlayerData( game )
        
        -- Last thing we do is fetch the current game info from the sqldb

        soulsurvivor.info.lastupdate = 0.5
    end 
    soulsurvivor.info.lastupdate = soulsurvivor.info.lastupdate - dt
end 

---------------------------------------------------------------------------------

local function runGameStep( game, frame, dt )

    -- Check userdata (incoming) and create changes in game
    applyGameInputs( game )

    -- Once websockets added - push notifications to users in game
    updateGameState( game, frame, dt )
end 

---------------------------------------------------------------------------------
-- Iterate each game and run a step 
--   TODO: This will run a child proc for each game runnning with a complete lua env

local function runModule( mod, frame, dt )

    for k, game in pairs(mod.data.games) do 

        if(game == nil) then 
            moduleError("Game Invalid: ", k) 

        else
            runGameStep( game, frame, dt )
        end
    end
end 

---------------------------------------------------------------------------------
-- Gets a cleaned up gameobject (less data)
local function getGameObject(gameobj)

    local gameobj = {
        name        = gameobj.name,
        gamename    = gameobj.gamename, 
        maxsize     = gameobj.maxsize,
        people      = gameobj.people,
        owner       = gameobj.owner, 
        private     = gameobj.private, 
        state       = gameobj.state or {},
        frame       = gameobj.frame,
        time        = gameobj.time,

        ws_port     = gameobj.ws_port,
    }
    return gameobject
end 

---------------------------------------------------------------------------------

local function createGame( uid, name )

    -- create a match - players will join this
    local gameobj = {

        name 	    = modulename,
        gamename    = name,
        sqlname     = "TblGame"..soulsurvivor.info.name..name,
        maxsize	    = MAXIMUM_GAMESIZE,

        -- list of user ids that are in the party
        people 		= {},

        owner 		= uid,
        -- no one can read this obj without auth (TODO: Add client password for this)
        private 	= true,

        -- index to the first person who is the creator/leader
        leader 		= 1,
        round       = {},
        -- Phase timeouts are set using this
        phasetime   = 0, 

        frame       = 0,
        time        = 0.0,

        state       = rounds.GAME_STATE.GAME_JOINING,
    }

    createGameState(gameobj)
    soulsurvivor.data.games[name] = gameobj 
    return gameobj
end

---------------------------------------------------------------------------------
-- Game has been exited by owner, then close it down.
--  TODO: Add promotion if there are enough players
local function closeGame( game, uid, name )

    if(game.owner ~= uid) then return nil end
    games.gameClose( uid, name )
    soulsurvivor.data.games[name] = nil
end

---------------------------------------------------------------------------------

local function updateGame( uid, name, body )

    local gameobj = soulsurvivor.data.games[name]
    if(gameobj == nil) then return nil end

    local res = nil 
    -- Check all the incoming data we care about. 
    if(body and string.len(body) > 0) then 
        local data = json.decode(body)

        if(data.state == rounds.GAME_STATE.EXIT) then 
            print("[ updateGame ] EXITING GAME")
            res = closeGame( gameobj, uid, name )
        end

        -- Handle different updates as per user update. Must be in correct state or
        --    update is ignored!
        if(gameobj.round and data and type(data) == "table") then 
            res = rounds.processround(gameobj, data)
        end 
    end 

    return res
end

---------------------------------------------------------------------------------

local function getTables( )

    sqlapi.setConn(soulsurvivor.conn)
    local jsontbl = {}
    p(soulsurvivor.conn)
    for k ,v in pairs(SQLITE_TABLES) do
        p(k, tablelimit)
        local tbl = sqlapi.getTable( k, tablelimit )
        jsontbl[k] = tbl
    end
    sqlapi.setConn(soulsurvivor.prevconn)
    return json.encode(jsontbl)
end

---------------------------------------------------------------------------------
soulsurvivor.init        = initModule
soulsurvivor.run         = runModule
soulsurvivor.creategame  = createGame
soulsurvivor.updategame  = updateGame

-- soulsurvivor.gettables   = getTables

return soulsurvivor

---------------------------------------------------------------------------------