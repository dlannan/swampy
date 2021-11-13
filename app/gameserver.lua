
local ffi   = require "ffi"

local tinsert   = table.insert

local uv    = require('uv')
local json  = require('lua.json')
local sql   = require "deps.sqlite3"
local timer = require "deps.timer"
local utils = require("lua.utils")
local bser  = require("lua.binser")

local sqlapi= require "lua.sqlapi"

local server = nil 

-- Make a websocket to allow games to talk to clients faster/better
WebSocket   = require("luvit-websocket")
BinSer      = bser
SFolk       = require("lua.smallfolk")

OSVehicle   = require("lua.opensteer.os-simplevehicle")
OSPathway   = require("lua.opensteer.os-pathway")
Vec3        = require("lua.opensteer.os-vec")

---------------------------------------------------------------------------------

local GAME_SCHEMA = "gid TEXT PRIMARY KEY, userid TEXT, username TEXT, playerdata TEXT"

---------------------------------------------------------------------------------
local function getSqlName(uid, name) 

    -- Get the user from the device id and determine module
    local udata = server.users[uid]
    if(udata == nil) then return nil end
    local module = udata.module
    if(module == nil) then return nil, nil end

    local sqlname = "TblGame"..module..name
    return sqlname, module
end 

---------------------------------------------------------------------------------
-- Gets a cleaned up gameobject (less data)
local function getGameObject(gameobj)

    local slimobj = {
        name        = gameobj.name,
        gamename    = gameobj.gamename, 
        maxsize     = gameobj.maxsize,
        people      = gameobj.people,
        owner       = gameobj.owner, 
        private     = gameobj.private, 
        state       = gameobj.state,
        frame       = gameobj.frame,
        ws_port     = gameobj.ws_port,
        init        = gameobj.init,
        time        = gameobj.time,
    }
    return slimobj
end 

---------------------------------------------------------------------------------
-- Helper to run pcalled sqlite commands
local  run_exec = nil

---------------------------------------------------------------------------------
local function init( gserver, tbls )

    if(server == nil) then server = gserver end
    run_exec = sqlapi.run_exec
end

---------------------------------------------------------------------------------
-- GAMES
---------------------------------------------------------------------------------

---------------------------------------------------------------------------------
-- Update the user timeout info - resets the timeout so the user isnt disconnected by server
local function gameUserUpdate( uid, name )

    local sqlname, module = getSqlName( uid, name )
    if(sqlname == nil or module == nil) then return nil end 
    if(server.modules[module] == nil) then return nil end

    server.users[uid].timeout = server.modules[module].USER_TIMEOUT
end

---------------------------------------------------------------------------------
-- Check the user exists, return nil if it doesnt
local function gameCheckUser( uid, name )

    local sqlname, module = getSqlName( uid, name )
    if(sqlname == nil or module == nil) then return nil end 
    if(server.modules[module] == nil) then return nil end

    local game = server.modules[module].data.games[name]
    if(game == nil) then return nil end 

    local people = game.people
    if(people) then 
        for k,v in pairs(people) do 
            if(v.uid == uid) then return v, module end 
        end 
    end
    return nil
end

---------------------------------------------------------------------------------
-- Get the list of user ids in a game
local function gameGetUsers( uid, name )

    local sqlname, module = getSqlName( uid, name )
    if(sqlname == nil or module == nil) then return nil end 
    if(server.modules[module] == nil) then return nil end

    local game = server.modules[module].data.games[name]
    if(game == nil) then return nil end 
    local people = game.people
    if(people) then return people end
    return nil
end

---------------------------------------------------------------------------------
-- Assuming you found a game and have a valid uid, join the game
local function gameJoin( uid, name, ishost )

    local udata = server.users[uid]
    if(udata == nil) then return nil end
    local username = udata.username 
    udata.host = tostring(ishost or false)

    local sqlname, module = getSqlName(uid, name)
    local smodule = server.modules[module]

    -- Check for a bunch of errors
    if(smodule == nil) then return nil end 
    if(smodule.data == nil) then return nil end 
    if(smodule.data.games == nil) then return nil end 
    local gameinfo = getGameObject(smodule.data.games[name])
    if(gameinfo == nil) then return nil end 

    if( gameCheckUser(uid, name) == nil ) then

        -- Add player, and set initial state
        -- "gid TEXT PRIMARY KEY, userid TEXT, username TEXT, state TEXT"
        local stmt = server.conn:prepare([[INSERT OR REPLACE INTO ]]..sqlname..[[ VALUES(?, ?, ?, ?);]])
        stmt:reset():bind( name, uid, username, "JOINED" ):step()
        stmt:close()

        sqlapi.setTableValue( "TblUserAccts", "uid", uid, "loginstate", "JOINED")

        -- Add username to people listed 
        tinsert(gameinfo.people, { uid = uid, username = udata.username, state = nil } )

        -- Set the gamename for the user 
        server.users[uid].gamename = name
        server.users[uid].loginstate = "JOINED"
        
        smodule.info.usercount = smodule.info.usercount + 1
        sqlapi.setModuleInfo(smodule.info)

        -- Notify the game a user has joined 
        if(smodule.joingame) then smodule.joingame(uid, name) end
    end 
    local gameinfostr = json.encode(gameinfo)

    return gameinfostr
end

---------------------------------------------------------------------------------
-- Create a new game - this makes a new sql table. 
--    The table lists rows of joined players
--    As players join/leave rows are inserted/removed
local function gameCreate( uid, name )

    print(uid, name)
    -- Clear name so it has no spaces, symbols etc 
    name = name:match("%w+")
    local sqlname, module = getSqlName(uid, name)
    if(sqlname == nil) then 
        -- This happens when a player gets disconnected (handle in client)
        p("[gameCreate Error] No valid db name")
        return nil 
    end

    -- check if table exists - if so, move on
    local status, result = sqlapi.checkTable(sqlname, GAME_SCHEMA)
    if(status == false) then 
        p("[Sqlite DB Error] Unable to create game: ", sqlname)
        return nil
    end

    -- Add table id to the game list
    -- "gid TEXT PRIMARY KEY, name TEXT, owner TEXT, userpool INTEGER, state TEXT"
    local stmt = server.conn:prepare([[INSERT OR REPLACE INTO TblGames VALUES(?, ?, ?, ?, ?, ?);]])
    stmt:reset():bind( sqlname, name, uid, tostring(1), uid, "WAITING" ):step()
    stmt:close()

----------- TODO: Here goes into seperate running lua module

    -- Start a server side game module
    local smodule = server.modules[module]
    if(smodule == nil) then return nil end 

    local gameinfo = smodule.creategame(uid, name)
    gameinfo.sqlname    = sqlname
    gameinfo.owner      = uid 
    smodule.data.games[name] = gameinfo
    smodule.info.gamecount = smodule.info.gamecount + 1
    sqlapi.setModuleInfo(smodule.info)
    local res = gameJoin( uid, name, true )

    -- Reload added people
    gameinfo = getGameObject(smodule.data.games[name])
    local gameinfostr = json.encode(gameinfo)

---------- Pipe from started game, returns game info
    return gameinfostr
end

---------------------------------------------------------------------------------
-- Find a game in the game list with a specific name 
--   May support pattern searches later
local function gameFind( uid, name )

    local sqlname, module = getSqlName(uid, name)
    if(sqlname == nil or module == nil) then return nil end 
    if(server.modules[module] == nil) then return nil end

    local sqlcmd = [[SELECT * FROM TblGames WHERE gid="]]..sqlname..[[" ]]
    local stat, res = pcall( run_exec, sqlcmd ) 
    if(stat == false) then 
        p("[Sqlite DB Error] ", res)
        return nil
    end 

    if(res == nil) then return nil end
    local foundgame = { found = sqlname } 
    local foundgamestr = json.encode(foundgame)
    return foundgamestr
end

---------------------------------------------------------------------------------
-- Assuming you found a game and have a valid uid, leave the game
local function gameLeave( uid, name )

    if(uid == nil) then return end
    local sqlname, module = getSqlName(uid, name)
    if(sqlname == nil or module == nil) then return nil end
    local smodule = server.modules[module]
    if(smodule == nil) then return nil end

    -- Deletion failure is not really an error - its means there is no table or lookup usually
    local sqlcmd = [[DELETE FROM ]]..sqlname..[[ WHERE userid="]]..uid..[["; ]]
    local stat, res = pcall( run_exec, sqlcmd ) 
    if(stat == false) then 
        p("[Sqlite DB Error] ", res)
    end 

    -- Update the user state in the server users table
    sqlapi.setTableValue( "TblUserAccts", "uid", uid, "loginstate", "WAITING")

    -- Remove person from people list
    gameinfo = smodule.data.games[name]
    if(gameinfo == nil) then return end
    local newpeople = {}
    if(gameinfo.people) then 
        for k,v in pairs(gameinfo.people) do 
            if(v.uid ~= uid) then 
                tinsert(newpeople, v)
            end 
        end
    end

    gameinfo.people = newpeople
    local user = server.users[uid]
    if(user) then 
        user.gamename = nil 
        user.loginstate = "WAITING"
    end 

    smodule.info.usercount = smodule.info.usercount - 1
    sqlapi.setModuleInfo(smodule.info)
    if(smodule.leavegame) then smodule.leavegame(user.uid, name) end

    return result
end

---------------------------------------------------------------------------------

local function gameRemove(sqlname) 

    -- delete the table, and remove game from games list
    local sqlcmd = [[DROP TABLE IF EXISTS ]]..sqlname..[[; ]]
    local stat, res = pcall( run_exec, sqlcmd ) 
    if(stat == false) then 
        p("[Sqlite DB Error] ", res)
        return nil
    end 

    local sqlcmd = [[DELETE FROM TblGames WHERE gid="]]..sqlname..[["; ]]
    local stat, res = pcall( run_exec, sqlcmd ) 
    if(stat == false) then 
        p("[Sqlite DB Error] ", res)
        return nil
    end 
end

---------------------------------------------------------------------------------
-- Only the owner can close the game or if all players leave
--      Table is deleted and the game no longer exists.
--      Game information may be stored later (especially created persons, traits, scenarios)
local function gameClose( uid, name )
    
    if(uid == nil) then return end
    local sqlname, module = getSqlName(uid, name)
    if(sqlname == nil or module == nil) then return nil end 
    if(server.modules[module] == nil) then return nil end

    server.modules[module].info.gamecount = server.modules[module].info.gamecount - 1
    sqlapi.setModuleInfo(server.modules[module].info)
    local gameinfo = server.modules[module].data.games[name]

    -- if there are people connected, then make them leave
    if(gameinfo and gameinfo.people) then 
        for k, user in pairs(gameinfo.people) do 
            gameLeave( user.uid, name )
            -- Notify the game a user has joined 
            if(smodule.leavegame) then smodule.leavegame(user.uid, name) end
        end 
    end 

    gameRemove(sqlname)
    server.modules[module].data.games[name] = nil
    return res
end

---------------------------------------------------------------------------------
-- The client requests a game update - sometimes sending body data
local function gameUpdate( uid, name, body )

    -- only update a game that this user is a member of 
    local user, module = gameCheckUser( uid, name)
    if(module == nil) then return nil end

    if(body) then body = bser.deserialize(body)[1] end
    if(body.state) then body.state = bser.deserialize(body.state)[1] end

    local gameinfotbl = server.modules[module].updategame(uid, name, body)
    local gameinfostr = bser.serialize(gameinfotbl)
    return gameinfostr
end

--------------------------------------------------------------------------------
-- Check all games in the games list are valid.
-- Criteria:
--     1. Game table exist
--     2. Game player count > 0 (update player)
--     3. Game owner is valid
local function checkAllGames( )

    local sqlcmd = [[SELECT * FROM TblGames;]]
    local stat, res = pcall( run_exec, sqlcmd ) 
    if(stat == false) then 
        p("[Sqlite DB Error] ", res)
        return nil
    end 

    if(res) then 
        for i = 1, #res[1] do 
            print(res.owner[i], res.name[i] )
            local game = gameFind( res.owner[i], res.name[i] )
            if(game==nil) then 
                gameRemove( res.gid[i] ) 
                print("NO GAME")
            end 
            local users = gameGetUsers( res.owner[i], res.name[i] )
            if(users==nil) then 
                gameClose( res.owner[i], res.name[i] )
                print("NO PLAYERS IN GAME")
            end
            local user = gameCheckUser( res.owner[i], res.name[i] )
            if(user==nil) then 
                gameClose( res.owner[i], res.name[i] )
                print("NO GAME OWNER")
            end 
        end 
    end
end

--------------------------------------------------------------------------------

local function getAllGames( )

    local sqlcmd = [[SELECT name, owner, players, gamedata FROM TblGames;]]
    local stat, res = pcall( run_exec, sqlcmd ) 
    if(stat == false) then 
        p("[Sqlite DB Error] ", res)
        return nil
    end 

    if(res) then 

        -- Convert to array with table rows with properties
        local games = {
            header  = res[0],
            rows    = {},
        }

        for i=1, #res[1] do 
            games.rows[i] = {
                name        = res[1][i],
                owner       = res[2][i],
                players     = res[3][i],
                gamedata    = res[4][i],
            }
        end 
        return games
    end 
    return nil
end


--------------------------------------------------------------------------------

local function getAllModules( )

    local sqlcmd = [[SELECT * FROM TblModuleStats;]]
    local stat, res = pcall( run_exec, sqlcmd ) 
    if(stat == false) then 
        p("[Sqlite DB Error] ", res)
        return nil
    end 

    local allmodules    = {}
    local header        = {}
    if(res) then 
        header = res[0]
        -- Iterate rows
        for i=1, #res[1] do 
            local info = {}
            for j=1, #header do
                local val = res[j][i]
                if(j>1) then val = tonumber(res[j][i]) end 
                info[j] = val
            end
            tinsert(allmodules, info)
        end 
    end
    return allmodules, header
end

--------------------------------------------------------------------------------

local function getAdminUsers( )

    -- Only allow access to some of admin data
    local users = { rows = {} }
    users.header = { "email", "name", "timeout", "banned", "ip", "state" }
    for k,v in pairs(server.admins) do 
        local row = { 
            email   = v.email,
            name    = v.name,
            timeout = tostring(v.timeout),
            banned  = tostring(v.banned), 
            ip      = v.ip, 
            state   = v.state, 
        }
        tinsert(users.rows, row)
    end
    return users
end

--------------------------------------------------------------------------------

local function getUserProfiles( )

    -- Only allow access to some of admin data
    local users = { rows = {} }
    users.header = { "uid", "username", "timeout", "loginstate", "gamename", "ip" }
    for k,v in pairs(server.users) do 
        local row = { 
            uid         = v.uid,
            username    = v.username,
            timeout     = tostring(v.timeout),
            loginstate  = v.loginstate, 
            ip          = v.ip, 
            gamename    = v.gamename, 
        }
        tinsert(users.rows, row)
    end
    return users
end

---------------------------------------------------------------------------------
-- Update the server.info and return it (only used by webadmin)

local function getServerInfo()

    if(server == nil) then return end 

    local games     = 0
    local players   = 0
    local hours     = 0
    
    for k,v in pairs(server.modules) do 
        if(v) then 
            if(v.data.games) then games = games + utils.tcount(v.data.games) end 
            if(v.data.users) then players = players + utils.tcount(v.data.users) end 
            if(v.info.uptime) then hours = hours + (v.info.uptime / 3600) end
        end
    end
    server.info.games   = games 
    server.info.players = players 
    server.info.hours   = hours

    return server.info
end

--------------------------------------------------------------------------------

local function getAllDatabases()

    local count = 0
    local fh = io.popen("ls -A1 ./data/*.sqlite3 | wc -l")
    if(fh) then 
        count = tonumber(fh:read("*a"))
        fh:close()
    end 
    return count 
end

--------------------------------------------------------------------------------

return {

    init            = init,

    gameFind        = gameFind,
    gameCreate      = gameCreate,
    gameJoin        = gameJoin,
    gameLeave       = gameLeave,
    gameClose       = gameClose,

    gameUpdate      = gameUpdate,
    gameUserUpdate  = gameUserUpdate,

    getAllGames     = getAllGames,
    getAllModules   = getAllModules,
    getAdminUsers   = getAdminUsers, 
    getUserProfiles = getUserProfiles,
    getAllDatabases = getAllDatabases,

    checkAllGames   = checkAllGames,
    getServerInfo   = getServerInfo,
}

--------------------------------------------------------------------------------
