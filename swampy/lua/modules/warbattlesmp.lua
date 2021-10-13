
-- Make a websocket to allow games to talk to clients faster/better
local WebSocket = require("luvit-websocket")

---------------------------------------------------------------------------------
-- A name for the game. 
local modulename      = "WarBattlesMP"

-- General game operation:
--    Drop in play. Can join any game any time. 
--    Once joined, increase amount of tanks to match players. 
--    Update character positions and rockets
--    Run tanks AI
--    Check if tanks are exploded - respawn if needed
--    Update Player list and player scores
--    If player exit, then reduce AI tanks (just drop a respawn)
--    If no players for 5 minutes, drop game

---------------------------------------------------------------------------------
-- Each entry in this table creates a sqltable for use in this module
local SQLITE_TABLES     = {
    ["gamedata"]      = { create = "desc TEXT, data TEXT" },
}

local allWSServers      = {}

-- ---------------------------------------------------------------------------
-- User defined events - these are handled in your module
local USER_EVENT 	= {
	REQUEST_GAME 	= 1,
	POLL 			= 2,

	REQUEST_READY	= 10,
	REQUEST_START 	= 20,
	REQUEST_WAITING = 30,
	REQUEST_ROUND 	= 40,
    REQUEST_PEOPLE 	= 41,

	-- Some War Battle Specific Events 
	PLAYER_STATE 	= 50, 		-- Generic DO EVERYTHING state 

	-- Smaller simple states (should use this TODO)
	PLAYER_SHOOT	= 60,		-- Player lauched a rocket 
	PLAYER_HIT		= 70,		-- Client thinks rocket hit something - server check
	PLAYER_MOVE 	= 80,		-- Movement has occurred update server
}

---------------------------------------------------------------------------------
-- Required properties are: 
--   name, and sqltables if you want sql persistent data
local warbattlempgame        = {
    -- You must set this. Or the user will be logged out with a single update
    USER_TIMEOUT    = 120,      

    name            = modulename,    
    sqltables       = SQLITE_TABLES,
}

---------------------------------------------------------------------------------
-- Run an individual game step. 
--   The game operations occur here. Usually:
--     - Check inputs/changes
--     - Apply to game state
--     - Output state changes
--     - Update game sync 
-- 
---------------------------------------------------------------------------------
-- Check state 
local function checkState( game )

    if(game.state) then 
        for i,v in ipairs(game.state) do 
            -- kill state if lifetime is old
            if(v and game.frame > v.lt) then 
                table.remove(game.state, i)
            end 
        end 
        -- Allows client to sync to the module frame
        game.state.frame = game.frame
    end 
end

---------------------------------------------------------------------------------
--    TODO: There may be a need to run this in a seperate Lua Env.
local function runGameStep( game, frame, dt )

    game.frame = frame
    checkState(game.state)

    if(game.state) then 
        for i,v in ipairs(game.state) do 
            -- Do anything with states - collision, scoring.. etc

        end 
    end 
end 

---------------------------------------------------------------------------------
-- Main run loop for the module. 
--    There are no real restrictions here. If you lock the runtime,
--    This modules thread will lock. The server may kick the module.
warbattlempgame.run          = function( mod, frame, dt )

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
warbattlempgame.creategame   = function( uid, name )

    local gameobj = {
        name        = modulename,
        gamename    = name, 
        sqlname     = "TblGame"..modulename,
        maxsize     = 4,
        people      = {},
        round       = {},
        owner       = uid, 
        private     = true, 
        state       = {},
        frame       = 0,
        ws_port     = 9999,
    }

    local ws_server = WebSocket.server.new():listen(gameobj.ws_port)
    print("WebSocket server running on port "..gameobj.ws_port)
    ws_server:on("connect", function(client)
        print("Client connected.")
        client:send("random message")
    end)

    ws_server:on("data", function(client, message)
        print("New data from client ", client)
        print(message)
        print("Responding by mirroring")
        client:send(message)
    end)

    ws_server:on("disconnect", function(client)
        print("Client " .. client.id .. " disconnected.")
    end)
    allWSServers[gamename] = ws_server

    warbattlempgame.data.games[name] = gameobj 
    return gameobj
end 

---------------------------------------------------------------------------------
-- Update provides feedback data to an update request from a game client. 
warbattlempgame.updategame   =  function( uid, name , body )

    -- get this game assuming you stored it :) and then do something 
    local game =  warbattlempgame.data.games[name] 
    if(game == nil) then return nil end 

    local result = nil
    -- -- Cleanup states in case there are old ones 
    checkState( game )

    -- Check if we have incoming game states
    if(body) then 
        -- State from user has been sent. If lifetime is 0 or null, then clear at next step
        if(body.uid and body.event == USER_EVENT.PLAYER_STATE) then 
            if(body.state) then 
                body.state.lt = (body.state.lt or 0) + game.frame
                table.insert(game.state, body.state)
                result = game.state
            end
        end 
        -- State from user has been sent. If lifetime is 0 or null, then clear at next step
        if(body.uid and body.event == USER_EVENT.REQUEST_GAME) then 
            result = game
        end 

        if(body.uid and body.event == USER_EVENT.REQUEST_ROUND) then 
            result = game.state
        end 

        if(body.uid and body.event == USER_EVENT.REQUEST_PEOPLE) then 
            result = game.people
        end 
    end

    -- Return some json to players for updates 
    return result
end 

---------------------------------------------------------------------------------
return warbattlempgame
---------------------------------------------------------------------------------
