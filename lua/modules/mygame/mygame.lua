---------------------------------------------------------------------------------
-- A name for the game. 
local mymodulename    = "MyGame"

---------------------------------------------------------------------------------
-- Each entry in this table creates a sqltable for use in this module
local SQLITE_TABLES     = {
    ["gamedata"]      = { create = "desc TEXT, data TEXT" },
}

---------------------------------------------------------------------------------
-- Required properties are: 
--   name, and sqltables if you want sql persistent data
local mygame        = {
    -- You must set this. Or the user will be logged out with a single update
    USER_TIMEOUT    = 120,      

    name            = mymodulename,    
    sqltables       = SQLITE_TABLES,
}

---------------------------------------------------------------------------------
-- Run an individual game step. 
--    TODO: There may be a need to run this in a seperate Lua Env.
local function runGameStep( game, frame, dt )
end 

---------------------------------------------------------------------------------
-- Main run loop for the module. 
--    There are no real restrictions here. If you lock the runtime,
--    This modules thread will lock. The server may kick the module.
mygame.run          = function( mod, frame, dt )

    for k, game in pairs(mod.data.games) do 
        if(game == nil) then 
            moduleError("Game Invalid: ", k) 
        else
            runGameStep( game, frame, dt )
        end
    end
end 

---------------------------------------------------------------------------------
-- Create a new game in this module. 
--    Each game can be tailored as needed.
mygame.creategame   = function( uid, name )

    local gameobj = {
        name        = mymodulename,
        gamename    = name, 
        sqlname     = "TblGame"..mymodulename,
        maxsize     = 4,
        people      = {},
        owner       = uid, 
        private     = true, 
        state       = "something",
    }
    -- Do something with mygameobject 
    mygame.data.games[name] = gameobj 
    return gameobj
end 

---------------------------------------------------------------------------------
-- Update provides feedback data to an update request from a game client. 
mygame.updategame   =  function( uid, name , body )

    -- get this game assuming you stored it :) and then do something 
    local game =  mygame.data.games[name] 
    if(game == nil) then return nil end 
    -- Return some json to players for updates 

    local gamedata = { 
        data1 = "test",
        data2 = 12345,
        data3 = { a = 1, b = "2" },
    }
    return gamedata
end 

---------------------------------------------------------------------------------
return mygame
---------------------------------------------------------------------------------
