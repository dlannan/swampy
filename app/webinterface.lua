local ffi = require("ffi")

local fs        = require('deps.fs')
local liluat    = require("lua.liluat")
local url       = require("lua.url")
local aes       = require('lua.aes')

local utils     = require("lua.utils")

local games     = require "app.gameserver"

require('lua.pretty-print')

---------------------------------------------------------------------------------
--- Templates 
local loginpage         = fs.readFileSync("admin/html/login.html")
local logoutpage        = fs.readFileSync("admin/html/logout.html")
local fourOfour_html    = fs.readFileSync("admin/html/404.html")
-- Partials


---------------------------------------------------------------------------------
-- Dashbard data

local dataserver    = nil

local ddata = {
    { url = '/dashboard.html', title = "Dashboard", icon = "glyphicon-dashboard", desc = "  Summary", count=0},
    { url = '/modules.html', title = "Modules", icon = "glyphicon-cog", desc = "  Game plugin", count=1},
    { url = '/games.html', title = "Games", icon = "glyphicon-play", desc = "  In play", count=7},
    { url = '/users.html', title = "Users", icon = "glyphicon-user", desc = "  Administrators", count=23},    
    { url = '/profiles.html', title = "Profiles", icon = "glyphicon-briefcase", desc = "  All users", count=39},
    { url = '/database.html', title = "Database", icon = "glyphicon-list-alt", desc = "  Tables", count=20},
}

local datalookup = {}
for k,v in pairs(ddata) do datalookup[v.url] = v end

---------------------------------------------------------------------------------

local function init(server)

    dataserver = server 
end 

---------------------------------------------------------------------------------

local function getServerData()

    info = games.getServerInfo()
    local sdata =  { 
        modules = utils.tcount(dataserver.server.modules), 
        games = info.games, 
        hours = math.floor(info.hours), 
        players = info.players, 
    }
    return sdata
end

---------------------------------------------------------------------------------

local function updateDData()

    local info = getServerData()
    ddata[2].count = info.modules
    ddata[3].count = info.games
    ddata[4].count = utils.tcount(dataserver.server.admins)
    ddata[5].count = info.players
    ddata[6].count = games.getAllDatabases()
end

---------------------------------------------------------------------------------

local function getDashboard( client, req, res, body )

    -- Get info about source url 
    local sitedata      = datalookup[req.url] or datalookup['/dashboard.html']

    -- Update ddata
    updateDData()

    -- Get the url - this determines state (index, pages, users etc)
    local dash          = fs.readFileSync("admin/html/dashboard.html")
    local dash_tpl      = liluat.compile(dash)

    local dashnav       = fs.readFileSync("admin/html/partials/dashboard_nav.tpl")
    local dashnav_tpl   = liluat.compile(dashnav)
    
    local adminuser     = dataserver.isAdminLoggedin(client)
    local dashnav_html  = liluat.render(dashnav_tpl, {pages = ddata, user = adminuser or "none"})

    local dashmenu      = fs.readFileSync("admin/html/partials/dashboard_menu.tpl")
    local dashmenu_tpl  = liluat.compile(dashmenu)
    local dashmenu_html = liluat.render(dashmenu_tpl, {pages = ddata, active = req.url})

    local dashmodal     = fs.readFileSync("admin/html/partials/modal_edit.tpl")
    local dashmodal_tpl = liluat.compile(dashmodal)
    local dashmodal_html = liluat.render(dashmodal_tpl, {pages = ddata})

    local dash_data = { 
        dashboard_navbar    = dashnav_html, 
        dashboard_menu      = dashmenu_html,
        modal_edit          = dashmodal_html,
        data                = sitedata,
        info                = dataserver.server.info,
        panel               = "",
        panel_script        = "<script></script>",
    }

    -- Only load the summary if its needed 
    if(sitedata.url == "/dashboard.html") then 

        local dashsumm      = fs.readFileSync("admin/html/partials/dashboard_summary.tpl")
        local dashsumm_tpl  = liluat.compile(dashsumm)
        local summary_data  = { data = getServerData() }
        dash_data.dashboard_summary   = liluat.render(dashsumm_tpl, summary_data)
    end

    if(sitedata.url == "/modules.html") then 

        local modpanel = fs.readFileSync("admin/html/partials/modules_panel.tpl")
        local modjs = fs.readFileSync("admin/js/partials/modules_panel.js")
        local modjs_tpl = liluat.compile(modjs)
        local modpanel_tpl = liluat.compile(modpanel)
        local alldata, hdr = games.getAllModules()
        dash_data.panel   = liluat.render(modpanel_tpl, { data = alldata, header = hdr })
        dash_data.panel_script = liluat.render(modjs_tpl, { data = alldata })
    end 

    if(sitedata.url == "/games.html") then 

        local gdata = games.getAllGames()
        local gamespanel = fs.readFileSync("admin/html/partials/games_panel.tpl")
        local gamespanel_tpl = liluat.compile(gamespanel)
        dash_data.panel   = liluat.render(gamespanel_tpl, { data = gdata })
    end 

    if(sitedata.url == "/users.html") then 

        local udata = games.getAdminUsers()
        local userspanel = fs.readFileSync("admin/html/partials/users_panel.tpl")
        local userspanel_tpl = liluat.compile(userspanel)
        dash_data.panel   = liluat.render(userspanel_tpl, { data = udata, adminuser = adminuser })
    end 

    if(sitedata.url == "/profiles.html") then 
        local udata = games.getUserProfiles()
        local userspanel = fs.readFileSync("admin/html/partials/profiles_panel.tpl")
        local userspanel_tpl = liluat.compile(userspanel)
        dash_data.panel   = liluat.render(userspanel_tpl, { data = udata })
    end 

    local dash_render = liluat.render(dash_tpl, dash_data)
    if(dash_render == nil) then dash_render = fourOfour_html end
    print(utils.getcookie(res, "sessionId"))
    utils.sendhtml( res, dash_render )
end 

---------------------------------------------------------------------------------

local function loginPage(client, req, res, body)

    utils.sendhtml( res, loginpage )
end

---------------------------------------------------------------------------------

local function logoutPage(client, tcpserve, req, res, body)

    local qdata = {uname = nil, psw = nil}
    if(body and string.len(body) > 0) then  qdata = url.parseQuery(body) end
    tcpserve.logoutAdminToken(client, qdata.uname, qdata.psw)
    utils.sendhtml( res, logoutpage )
end

---------------------------------------------------------------------------------

local function invalidUser(client, tcpserve, req, res, body)

    local errorPage = nil
    local qdata = {uname = nil, psw = nil}

    if(body and string.len(body) > 0) then  qdata = url.parseQuery(body) end
    local key, pwtoken = utils.getcookie(req, "sessionId")
    if( tcpserve.checkAdminToken(client, qdata.uname, qdata.psw, pwtoken) == nil ) then 
        errorPage = true 
    end

    if(errorPage) then 
        p("[Bad Login] ", body)
        loginPage(client, req, res, body)
        return true
    end
    return nil
end

---------------------------------------------------------------------------------

local function getModuleData(client, req, res, body)

    local urltbl = url.parse(req.url)
    if(urltbl.query.name == nil or string.len(urltbl.query.name) == 0) then 
        utils.sendhtml( res, "" ) 
        return 
    end

    local modname = urltbl.query.name
    local mod = dataserver.server.modules[modname]
    if(mod == nil) then utils.sendhtml( res, "" ); return end
    if(mod.gettables == nil) then utils.sendhtml( res, "" ); return end
    local jsontbl = mod.gettables()
    utils.sendjson( res, jsontbl )
end

---------------------------------------------------------------------------------

return {
    init            = init, 

    userfunc        = userfunc,
    loginPage       = loginPage,
    logoutPage      = logoutPage,
    invalidUser     = invalidUser,

    getDashboard    = getDashboard,

    getModuleData   = getModuleData,
}