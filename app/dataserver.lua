
local ffi   = require "ffi"

local tinsert   = table.insert

local uv        = require('uv')
local json      = require('lua.json')
local aes       = require "lua.aes"
local utils     = require "lua.utils"

local sql       = require "deps.sqlite3"
local timer     = require "deps.timer"

local sqlapi    = require "lua.sqlapi"
local games     = require "app.gameserver"

local binser    = require "lua.binser"

local cfg       = require("app.server-config")
local pipe      = require("lua.pipe")

-- Current user profile connection state
local CONNECT_STATE = {

    UNKNOWN         = "UNKNOWN",
    LOGGING_IN      = "LOGGING_IN",
    WAITING         = "WAITING",
    LOGGED_IN       = "LOGGED_IN",
}

---------------------------------------------------------------------------------
-- This will be dynamic in the future. Able to be created in the admin panel
local server    = {

    conn            = nil,   -- sql db

    frame           = 0,     -- What frame the server is running. For perf and reports.
    game_check      = 0,
    modules         = {},
    users           = {},
    
    info            = {
        diskusage   = 0,
        bwusage     = 0,
        games       = 0,
        hours       = 0,
        players     = 0,
    },

    -- Specific users for administration of swampi
    admins          = {},
    -- Logged in admins - if they are not in here, then they need to log again
    ipadmins        = {},

    apitokens       = {},    -- API tokens used for access - each game module gets one
    bearertokens    = {},    -- successful login and assignment token
    userids         = {},    -- user device id
    loginTokens     = {},    -- short lived tokens used to handshake with user


    UPDATE_TICKS    = cfg.UPDATE_TICKS,
}

local run_exec  = nil       -- Helper for making running things easier with sql

---------------------------------------------------------------------------------

local SERVER_PORT     = 17000

-- local SERVER_FILE     = ""    -- use this for in-mem db.
local SERVER_FILE     = "swampy"

local SQLITE_TABLES   = {

    ["TblAPITokens"]    = { create = "id TEXT PRIMARY KEY, token TEXT" },
    ["TblDeviceIds"]    = { create = "id TEXT PRIMARY KEY, token TEXT" },
    ["TblBearerTokens"] = { create = "tag TEXT PRIMARY KEY, uid TEXT, timein TEXT" },
    ["TblUserAccts"]    = { create = "uid TEXT PRIMARY KEY, module TEXT, username TEXT, loginstate TEXT, lang TEXT, idletimeout INTEGER, logintime INTEGER" },

    -- Collate data on a module
    ["TblModuleStats"]  = { create = [[name TEXT PRIMARY KEY, dataread INTEGER, datawrite INTEGER,
    lastupdate INTEGER, gamecount INTEGER, uptime INTEGER, usercount INTEGER, activity INTEGER]] },


    -- Games are added/removed from this table
    ["TblGames"]        = { create = "gid TEXT PRIMARY KEY, name TEXT, owner TEXT, players TEXT, userpool INTEGER, gamedata TEXT" },
    ["TblUserPool"]     = { create = "upid TEXT PRIMARY KEY, gid TEXT, username TEXT, uid TEXT" },
}

---------------------------------------------------------------------------------
-- SERVER SETUP
---------------------------------------------------------------------------------

local function readAdmins()

    local admins = nil
    local fh = io.open(cfg.ADMIN_DATA, "r")
    if( fh ) then 
        local instr = fh:read("*a") 
        admins = binser.deserialize(instr)[1]
        fh:close()
    end
    -- p(admins)
    return admins
end

---------------------------------------------------------------------------------

local function writeAdmins()

    local outstr = binser.serialize(server.admins)
    local fh = io.open(cfg.ADMIN_DATA, "w")
    if( fh ) then fh:write(outstr); fh:close()  end 

end 

---------------------------------------------------------------------------------
-- Get the sqltables this game module uses - its for the admin and other
local function initModuleSql( mod )

    mod.gettables    = function() 

        mod.sql.prevconn = sqlapi.getConn()
        sqlapi.setConn(mod.sql.conn)
        local jsontbl = {}
        for k ,v in pairs(mod.sqltables) do
            local tbl = sqlapi.getTable( k, tablelimit )
            jsontbl[k] = tbl
        end
        sqlapi.setConn(mod.sql.prevconn)
        return json.encode(jsontbl)
    end 
end 

---------------------------------------------------------------------------------

local function initModule( mod )

    mod.info    = {
        name        = mod.name,
        usercount   = 0,
        gamecount   = 0, 
        activity    = 0, 
        dataread    = 0,
        datawrite   = 0,
        uptime      = 0,
        lastupdate  = 0.0,
    }

    mod.data    = {
        games   = {},     -- running games using this module
        users   = {},     -- available logged in users
        updates = {},     -- updates queued in order by timestamp sent
    }

    mod.sql = {}   
    mod.sql.prevconn = sqlapi.getConn()
    mod.sql.conn = sqlapi.init(mod.name, mod.sqltables)
    sqlapi.checkTables( mod.sqltables )
    sqlapi.setConn(mod.sql.prevconn)

    initModuleSql(mod)
    if(mod.init and type(mod.init) == "function") then mod.init(mod) end
    mod.gettables()
end 

---------------------------------------------------------------------------------

local function init( varg )

    if(varg[2] == "rebuild") then 
        os.execute("rm "..SERVER_FILE)
    else
        server.admins = readAdmins() or {}
        if(server.admins == nil) then server.admins = {} end
        -- p(server.admins)
    end

    server.conn     = sqlapi.init(SERVER_FILE, SQLITE_TABLES)
    games.init(server)

    if(server.conn == nil) then 

        p("[Sqlite DB Error] Problem connecting to sqlite server.")
    else 
        -- Assign the run exec from the sqlapi
        run_exec = sqlapi.run_exec

        -- Read in the token table for fast lookup. 
        status, server.apitokens = pcall( run_exec, "SELECT id FROM TblAPITokens" ) 
        if(status == false) then 
            p("[Sqlite DB Error] ", server.apitokens)
        end 

        local modstr = utils.ls("lua/modules")       
        local modules = utils.split(modstr, "\n")

        for k,v in ipairs(modules) do 

            if(v ~= '') then 
                -- Try requiring the module
                local basename = string.match(v, "^(.*)")
                local ismod = require("lua.modules."..basename.."."..basename)
                if(ismod.name) then 
                    server.modules[ismod.name] = ismod 
                end
            end
        end 
    end 

    for k, module in pairs(server.modules) do 
        if(module and module ~= "swampy") then 
            initModule(module) 
        end 
    end
end

---------------------------------------------------------------------------------
-- Cleanup db

local function close(  )
    if(server.conn) then 
      p("[SQlite DB: Closing.")
        server.conn:close() 
    end 
end 

---------------------------------------------------------------------------------
-- USER LOGIN
---------------------------------------------------------------------------------


local function getpwtoken( useremail, password )

    -- Gen an initial id from useremail and password - aes crypt is nice.
    local pwtoken = aes.ECB_256(aes.encrypt, cfg.KEY, useremail..password..cfg.GBG)
    return pwtoken --string.gsub(pwtoken, "%W", "")
end

---------------------------------------------------------------------------------

local function getAdminToken( useremail, pwtoken )

    local token =  aes.ECB_256(aes.encrypt, cfg.KEY, useremail..cfg.GBG..pwtoken)
    return string.gsub(token, "%W", "")
end 

---------------------------------------------------------------------------------

local function checkAPIToken( token )
    -- TODO - this needs to check server.apitokens list
    --        They can only be added in the admin console. No code methods here
    if(token == cfg.API_GAME_TOKEN) then return true end 
    return nil
end 

---------------------------------------------------------------------------------

local function checkLoginToken( token )
  
  -- Once a login token is used, then destroy it (only one use at login!)
  if( server.loginTokens[token] ) then 
      server.loginTokens[token] = nil
      return true
  end 
  return nil
end 
---------------------------------------------------------------------------------

local function checkToken( token )
  
    if( server.bearertokens[token] ) then 
        return true
    end 
    return nil
end 

---------------------------------------------------------------------------------

local function checkUserId( userid )
  
  if( server.userids[userid] ) then 
      return true
  end 
  return nil
end 


---------------------------------------------------------------------------------

local function logoutAdminToken( client, useremail, password )

    -- Check ip+port lookup. This is our "connected" user.
    local admintoken =  nil 
    if(useremail and password) then 
        local pwtoken = getpwtoken(useremail, password)
        admintoken = getAdminToken(useremail, pwtoken)
    else 
        admintoken = server.ipadmins[client.ip..cfg.GBG]
    end 
    if(admintoken == nil) then return nil end 
    adminuser = server.admins[admintoken]
    if(adminuser == nil) then return nil end 
    server.ipadmins[client.ip..cfg.GBG] = nil
    
    adminuser.state = "LOGGED_OUT"
end

---------------------------------------------------------------------------------

local function checkAdminToken( client, useremail, password, pwtoken )

    --    p(server.admins, admintoken)
    local admintoken = nil
    --p("[Admin User]", server.ipadmins, pwtoken, useremail, password)

    if(pwtoken == nil) then 

        if(useremail == nil or password == nil) then 
            print("[Admin Token] Admin invalid credentials", useremail, password)
            return nil 
        end 

        -- Gen an initial id from useremail and password - aes crypt is nice.
        pwtoken = getpwtoken(useremail, password)
        admintoken = getAdminToken(useremail, pwtoken)
    else 

        -- Check ip+port lookup. This is our "connected" user.
        if(client == nil) then return nil end 
        admintoken = server.ipadmins[client.ip..cfg.GBG]
    end 

    if(admintoken == nil) then return nil end
    local adminuser = server.admins[admintoken]

    if( adminuser ) then 
        -- check timeout 
        local thistime = os.time()
        if(adminuser.state == "LOGGED_OUT") then 
            print("[Admin Token] Admin logged out.")
            return nil 
        end

        if(adminuser.pwtoken ~= pwtoken) then 
            print("[Admin Token] Admin no matching token.")
            return nil 
        end

        if(thistime - adminuser.timeout > cfg.LOGIN_TIMEOUT) then 
            if(adminuser.state == "LOGGED_IN") then 
                adminuser.state = "TIMEOUT"
                -- This will force a login.
                return nil 
            end 
            if(adminuser.state == "TIMEOUT") then 
                if(adminuser.pwtoken == pwtoken) then 
                    adminuser.state = "LOGGED_IN"
                    adminuser.timeout = thistime

                    server.ipadmins[client.ip..cfg.GBG] = admintoken
                    return true
                end 
                -- This will force a login.
                return nil 
            end 
        end

        server.ipadmins[client.ip..cfg.GBG] = admintoken
        return true
    end 

    print("[Admin Token] Admin unknown error.")
    return nil
end 

---------------------------------------------------------------------------------

local function newAdmin( client, useremail, pwtoken )

    local newadmin = { 
        email       = useremail, 
        admin       = true, 
        pwtoken     = pwtoken,
        timeout     = os.time(), 
        banned      = false, 
        ip          = client.ip, 
        port        = client.port, 
        name        = utils.genname(), 
        state       = "LOGGED_IN",
    }
    return newadmin
end
---------------------------------------------------------------------------------

local function checkAdminLogin( client, useremail, password )

    if(useremail == nil or password == nil) then return nil end 
    if(string.len(useremail) == 0 or string.len(password) == 0) then return nil end

    local pwtoken = nil
    -- Gen an initial id from useremail and password - aes crypt is nice.
    pwtoken = getpwtoken( useremail, password )

    -- Check ip+port lookup. This is our "connected" user.
    local admintoken =  getAdminToken( useremail, pwtoken )
    adminuser = server.admins[admintoken]

    if(adminuser) then 
        if(adminuser.pwtoken ~= pwtoken) then print("BAD PWTOKEN"); return nil end 
        if(server.admins[admintoken].banned ~= false) then print("BANNED"); return nil end
        adminuser.state = "LOGGED_IN"
        server.ipadmins[client.ip..cfg.GBG] = admintoken
        -- print("[checkAdminLogin] ",client.ip, client.port, admintoken)   -- TODO: Log this
        return true 
    else 

        -- Check is there are any admins - if not then this is the first one(becomes admin!)
        if(utils.tcount(server.admins) == 0) then

            local newadmin = newAdmin( client, useremail, pwtoken )
            server.admins[admintoken] = newadmin
            server.ipadmins[client.ip..cfg.GBG] = admintoken
            writeAdmins()
            return true
        end    
    end
    return nil
end 

---------------------------------------------------------------------------------

local function isAdminLoggedin( client )

    -- Check ip+port lookup. This is our "connected" user.
    local admintoken =  server.ipadmins[client.ip..cfg.GBG]
    if(admintoken == nil) then return nil end
    adminuser = server.admins[admintoken]
    if(adminuser and adminuser.state == "LOGGED_IN") then return adminuser.name end 
    return nil 
end 

---------------------------------------------------------------------------------

local function setAdminUsername( client, newusername )

    -- Check ip+port lookup. This is our "connected" user.
    local admintoken =  server.ipadmins[client.ip..cfg.GBG]
    if(admintoken == nil) then return nil end
    adminuser = server.admins[admintoken]
    if(adminuser and adminuser.state == "LOGGED_IN") then 
        adminuser.name = newusername
        writeAdmins()
        return true
    end 
    return nil 
end 


---------------------------------------------------------------------------------

local function checkDevice( uid )

    local sqlcmd = [[SELECT * FROM TblDeviceIds WHERE id="]]..uid..[[" ]]
    local stat, res = pcall( run_exec, sqlcmd ) 
    if(stat == false) then 
        p("[Sqlite DB Error] ", res)
        return nil
    end 
    return res
end 

---------------------------------------------------------------------------------

local function loginUser( userid, uid )

    local usertoken = userid.."XX"..uid
    if( checkUserId(usertoken) == nil ) then 
        -- Add device to the DB
        local sqlcmd = [[INSERT OR REPLACE INTO TblDeviceIds VALUES ("]]..uid..[[", "]]..usertoken..[[") ]]
        local stat, err = pcall( run_exec, sqlcmd ) 
        if(stat == false) then 
            p("[Sqlite DB Error] ", err)
            return nil
        end 
        server.userids[userid] = usertoken
        server.loginTokens[usertoken] = userid
    else
        -- Already have a userid of this. ie Device and User already exist as is. 
    end 
    return usertoken
end 

---------------------------------------------------------------------------------

local function authenticateUser( logintoken, uid )

    -- Check for user and device first!
    if ( checkDevice(uid) == nil ) then return nil end
    if( checkLoginToken(logintoken) == nil ) then return nil end 

    local connecttime = string.format("%09d", os.clock()* 10000)
    local connecttag  = logintoken.."VV"..uid.."VV"

    local sqlcmd = [[INSERT OR REPLACE INTO TblBearerTokens VALUES ("]]..connecttag..[[","]]..uid..[[","]]..connecttime..[[") ]]
    local stat, err = pcall( run_exec, sqlcmd ) 
    if(stat == false) then 
        p("[Sqlite DB Error] ", err)
        return nil
    end 
    server.bearertokens[connecttag..connecttime] = uid
    return connecttag..connecttime
end 

---------------------------------------------------------------------------------
-- Generate new user info - this is the source for all users!!
local function newUserInfo( client, module, name, uid )
    -- Store this in users for quick lookup using device_id
    local userinfo = {
        uid         = uid,
        module      = module,      -- game module being used by this user
        username    = name, 
        gamename    = nil,
        loginstate  = CONNECT_STATE.UNKNOWN,
        lang        = cfg.DEFAULT_LANG,
        timeout     = cfg.DEFAULT_TIMEOUT,
        ip          = client.ip,
    }
    return userinfo
end 

---------------------------------------------------------------------------------
-- Remove a user from the connected user list. 
local function removeUser( uid )

    -- Check for user and device first! - dont remove nil user!
    if ( checkDevice(uid) == nil ) then return nil end

    local sqlcmd = [[DELETE FROM TblUserAccts WHERE uid="]]..uid..[["; ]]
    local stat, res = pcall( run_exec, sqlcmd ) 
    if(stat == false) then 
        p("[Sqlite DB Error] ", res)
        return nil
    end 
    server.users[uid] = nil
    return true
end

---------------------------------------------------------------------------------
-- The first connect always provide the module. This indicates what game the user 
--   is playing thus which module to assign the user to. 
-- NOTE: does not currently allow multiple games played by same user (security)
local function connectUser( client, module, name, uid )

    -- Check for user and device first!
    if ( checkDevice(uid) == nil ) then return nil end

    local logintime = os.time()
    local userdata = [["]]..uid..[[","]]..module..[[","]]..name..[[", "JOINING", "]]..cfg.DEFAULT_LANG..[[",]]..cfg.DEFAULT_TIMEOUT..[[,]]..logintime

    -- "uid TEXT PRIMARY KEY, userid TEXT, username TEXT, loginstate TEXT, lang TEXT, idletimeout INTEGER, logintime INTEGER"
    local sqlcmd = [[INSERT OR REPLACE INTO TblUserAccts VALUES (]]..userdata..[[) ]]
    local stat, err = pcall( run_exec, sqlcmd ) 
    if(stat == false) then 
        p("[Sqlite DB Error] ", err)
        return nil
    end 

    local userinfo = newUserInfo(client, module, name, uid)
    userinfo.loginstate = CONNECT_STATE.LOGGING_IN
    userinfo.logintime  = logintime

    server.users[uid] = userinfo
    print("[connectUser] User connected:", uid)
    if(server.modules[module]) then 
        tinsert(server.modules[module].data.users, uid)
    end 
    return userinfo
end 

---------------------------------------------------------------------------------

local function userUpdateName( uid, playername, lang )

    if(server.users[uid]) then 
        if(playername) then server.users[uid].username = playername end
        if(lang) then server.users[uid].lang = lang end
    end

    if(playername) then sqlapi.setTableValue( "TblUserAccts", "uid", uid, "username", playername ) end
    if(lang) then sqlapi.setTableValue( "TblUserAccts", "uid", uid, "lang", lang ) end

    -- If the user is in a game, update game details
    local user = server.users[uid]
    if(user and user.gamename) then 
        local gameinfo = server.modules[user.module].data.games[user.gamename]
        if(gameinfo and gameinfo.people) then 
            for k,v in ipairs(gameinfo.people) do 
                if(v.uid == uid and user.username ~= v.username) then 
                    v.username = user.username 
                    break
                end
            end
        end 
    end

    return json.encode({ })
end

---------------------------------------------------------------------------------
-- MODULES
---------------------------------------------------------------------------------
-- Currently very manual - this will be moved to a thread per module.
--   Each game module will have its own lua env and thread to update.
--   Req's will be passed in/out the thread.

local function updateModules(pipeFDs)

    server.frame = server.frame + 1
    for k, module in pairs(server.modules) do 
        if(module) then 
            module.info.uptime = module.info.uptime + cfg.UPDATE_TICKS   -- secs
            module.run(module, server.frame, cfg.UPDATE_RATE) 
        end 
    end 

    for k,user in pairs(server.users) do        
        if(user and user.module and user.gamename) then 
            user.timeout = user.timeout - server.UPDATE_TICKS
            -- Disconnect timeout user
            if(user.timeout <= 0.0) then 
                games.gameLeave(user.uid, user.gamename)
                user.module     = nil
                user.timeout    = 0
            end 
        end
        -- kick users after no connect in an hour
        if(user and (os.time() - user.logintime > cfg.CONNECT_TIMEOUT) ) then 
            removeUser(user.uid)
        end
    end

    if server.game_check <= 0 then 
        games.checkAllGames()

        local fh = io.popen("du -d 0 .")
        local output = fh:read("*a")
        fh:close()
        server.info.diskusage = tonumber(string.match(output, "^(%d+)"))

        server.game_check = cfg.GAME_CHECK_TIMEOUT

        for k, module in pairs(server.modules) do 
            if(module) then
                sqlapi.setModuleInfo(module.info)
            end
        end
    end
    server.game_check = server.game_check - cfg.UPDATE_TICKS

    -- local ok, temp = pipe.read(cfg.PIPE_ReadRouter, 16)
    -- if(ok > 6 and temp == "ServerOk") then 

    --     local str = "Server Tick: "..string.format("%.1f", server.game_check)
    --     pipe.write(cfg.PIPE_WriteHttps, str)
    --     p("[Pipe Read Data] "..temp)
    -- end
end

local function runModules( pipeFDs ) 

    pipe.close(cfg.PIPE_ReadHttps)
    pipe.close(cfg.PIPE_WriteRouter)

    local str = "Server Tick: "..string.format("%.1f", server.game_check)
    pipe.write(cfg.PIPE_WriteHttps, str)
    timer.setInterval( cfg.UPDATE_RATE, updateModules, pipeFDs )
end 

---------------------------------------------------------------------------------

return {
    init            = init,
    close           = close,

    importJSON      = sqlapi.importJSON,
    importJSONFile  = sqlapi.importJSONFile,

    getTable        = sqlapi.getTable,
    setTable        = sqlapi.setTable,
    checkTable      = sqlapi.checkTable,

    getpwtoken      = getpwtoken,

    checkAPIToken   = checkAPIToken,
    checkAdminLogin = checkAdminLogin,
    checkAdminToken = checkAdminToken,

    logoutAdminToken = logoutAdminToken,
    isAdminLoggedin = isAdminLoggedin,
    setAdminUsername= setAdminUsername,

    loginUser       = loginUser,
    checkToken      = checkToken,
    authenticateUser= authenticateUser,
    connectUser     = connectUser,
    userUpdateName  = userUpdateName,

    gameFind        = games.gameFind,
    gameCreate      = games.gameCreate,
    gameJoin        = games.gameJoin,
    gameLeave       = games.gameLeave,
    gameClose       = games.gameClose,

    gameUpdate      = games.gameUpdate,

    server          = server,
    runModules      = runModules,
}

---------------------------------------------------------------------------------
