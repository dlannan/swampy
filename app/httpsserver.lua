
package.path = package.path..";./deps/?.lua;./deps/?/init.lua"
package.path = package.path..";./deps/path/?.lua;./deps/stream/?.lua"
package.path = package.path..";./deps/luvit-websocket/?.lua"
package.path = package.path..";./deps/luvit-websocket/libs/?.lua"
package.path = package.path..";./deps/tls/?.lua"
---------------------------------------------------------------------------------

local ffi = require("ffi")

---------------------------------------------------------------------------------
local http      = require("http")
local https     = require("https")
local pathJoin  = require('luvi').path.join
local fs        = require('fs')
local uv        = require('uv')
local aes       = require('lua.aes')
local liluat    = require("lua.liluat")
local url       = require("lua.url")
local utils     = require("lua.utils")

---------------------------------------------------------------------------------
-- TODO: Make an arg, instead. This is very temp.
local SERVER_IP     = "0.0.0.0"
---------------------------------------------------------------------------------

require('lua.pretty-print')
local dbg       = require('lua.debugger')

-- TODO Make this our sqlite server
local tcpserve  = require("app.dataserver")
local wui       = require("app.webinterface")

---------------------------------------------------------------------------------
-- Init before assignments
tcpserve.init(args)
wui.init(tcpserve)

---------------------------------------------------------------------------------
-- API Handlers 
require("lua.api-handlers.userlogin")
require("lua.api-handlers.userauthenticate")
require("lua.api-handlers.userconnect")
require("lua.api-handlers.userupdate")

require("lua.api-handlers.datagettable")
require("lua.api-handlers.datasettable")

require("lua.api-handlers.gamecreate")
require("lua.api-handlers.gamefind")
require("lua.api-handlers.gamejoin")
require("lua.api-handlers.gameleave")
require("lua.api-handlers.gameclose")

require("lua.api-handlers.gameupdate")

-- Special admin only handlers - this needs login, and bearertoken to work!
local adminUpdate = require("lua.api-handlers.adminupdate")

---------------------------------------------------------------------------------

function notFound(res) 
	res.statusCode = 404
    utils.sendhtml( res, "404" )
end

---------------------------------------------------------------------------------

local function getFont(client, req, res) 

    -- TODO: Need to check with mime type really
    local font = fs.readFileSync("."..req.url)
    if font then 
        local ext = string.match(req.url, "%.(.*)$") or "ttf"
        local ctype = "font/"..ext
        utils.senddata( res, font, ctype)
    end
end

---------------------------------------------------------------------------------

local function getCSS(client, req, res) 

    -- TODO: Need to check with mime type really
    local css = fs.readFileSync("."..req.url)
    if css then utils.senddata( res, css, "text/css") end
end

---------------------------------------------------------------------------------

local function getJS(client, req, res) 

    -- TODO: Need to check with mime type really
    local js = fs.readFileSync("."..req.url)
    if js then utils.senddata( res, js, "text/javascript") end
end

---------------------------------------------------------------------------------

local function getHTML(client, req, res) 

    -- TODO: Need to check with mime type really
    local html = fs.readFileSync("./html/"..req.url)
    if html then utils.sendhtml( res, html ) end
end

---------------------------------------------------------------------------------

local function toData(client, req, res, body)

    if(string.len(body) == 0) then notFound(res); return end
    -- convert qeury
    local qdata = url.parseQuery(body)
    if(qdata.uname ~= nil and qdata.psw ~= nil) then 
        -- check token first
        if( tcpserve.checkAdminToken( client, qdata.uname, qdata.psw ) ) then 
            utils.setcookie(res, "sessionId", tcpserve.getpwtoken( qdata.uname, qdata.psw ))
            wui.getDashboard(client, req, res, body)
            return
        elseif( tcpserve.checkAdminLogin( client, qdata.uname, qdata.psw ) ) then 
            utils.setcookie(res, "sessionId", tcpserve.getpwtoken( qdata.uname, qdata.psw ))
            wui.getDashboard(client, req, res, body)
            return
        end 
    end 

    wui.loginPage(client, req, res)
end

---------------------------------------------------------------------------------

local function getImage(client, req, res)
    -- TODO: Need to check with mime type really
    local img = fs.readFileSync("."..req.url)
    local ext = string.sub(req.url, -3, -1)
    p("[Extension] ", ext)
    if img and ext:lower() == "png" then utils.senddata( res, img, "image/png") end
    if img and ext:lower() == "svg" then utils.senddata( res, img, "image/svg+xml") end
end

---------------------------------------------------------------------------------

local EndpointTbl = {
    ['/']                   = wui.loginPage,
    ['/login.html']         = wui.loginPage,
    ['/logout.html']        = function(client, req, res) wui.logoutPage(client, tcpserve, req, res) end,
    ['/index.html']         = wui.getDashboard,
    ['/database.html']      = wui.getDashboard,
    ['/users.html']         = wui.getDashboard,
    ['/games.html']         = wui.getDashboard,
    ['/edit.html']          = wui.getDashboard,
    ['/profiles.html']      = wui.getDashboard,
    ['/modules.html']       = wui.getDashboard,

    ['/dashboard.html']     = wui.getDashboard,

    -- An admin api
    ['/api/moduledata.json'] = wui.getModuleData,
    ['/api/adminupdate']    = adminUpdate,
}

local EnpointMatchTbl = {
    ['/login.php']          = toData,

    ['/css/images/(.*)%.png']   = getImage,
    ['/css/images/(.*)%.svg']   = getImage,

    ['/images/(.*)%.png']   = getImage,
    ['/fonts/(.*)%.woff']   = getFont,
    ['/fonts/(.*)%.woff2']  = getFont,
    ['/fonts/(.*)%.ttf']    = getFont,

    ['^/js/(.*)%.js$']      = getJS,
    ['^/css/(.*)%.css$']    = getCSS,
    ['^/css/(.*)%.map$']    = function(client, req, res) notFound(res) end,

--    ['^/(.*)%.html$']       = getHTML,
}

-- All api endpoints must match a complete path
-- TODO: Publish these for users to access!
-- Format: /api/v1/<token>/<feature>/<function>?<params>
-- Output: Always returns json. Minimum is empty json object {}
local EndpointAPITbl = {
    ['/user/login']         = api_userLogin or function() end,
    ['/user/authenticate']  = api_userAuthenticate or function() end,
    ['/user/connect']       = api_userConnect or function() end,
    ['/user/close']         = api_userClose or function() end,
    ['/user/update']        = api_userUpdate or function() end,

    ['/data/gettable']      = api_dataGetTable or function() end, 
    ['/data/settable']      = api_dataSetTable or function() end,

    ['/game/find']          = api_gameFind or function() end,
    ['/game/create']        = api_gameCreate or function() end,
    ['/game/join']          = api_gameJoin or function() end,
    ['/game/leave']         = api_gameLeave or function() end,
    ['/game/close']         = api_gameClose or function() end,

    ['/game/update']        = api_gameUpdate or function() end,
}

---------------------------------------------------------------------------------

local function handleEndpoints( client, req, res, body )

    local urltbl = url.parse(req.url)
    local path = urltbl.path

    local handled = nil
    local handleFunc = EndpointTbl[path]
    if(handleFunc) then handleFunc( client, req, res, body ); handled = true end 
    return handled
end

---------------------------------------------------------------------------------

local function handleEndpointMatch( client, req, res, body )

    local urltbl = url.parse(req.url)
    local path = urltbl.path
    local handled = nil
    for k,handleFunc in pairs(EnpointMatchTbl) do 
        local result = string.match( path, k )
        if( result ) then
            if(handleFunc) then 
                handleFunc(client, req, res, body)
                handled = true
                break 
            end
        end
    end
    return handled
end

---------------------------------------------------------------------------------

local function handleAPIEndpoints( client, req, res, body )

    local urltbl = url.parse(req.url)
    -- Split path to check token
    local path = urltbl.path
    local pathitems = utils.split(path, "/")

    if( tcpserve.checkAPIToken( pathitems[4] ) ~= true ) then return end
    local funcpath = ""
    for i=5, #pathitems do funcpath = funcpath.."/"..pathitems[i] end

    local handled = nil
    local handleFunc = EndpointAPITbl[funcpath]
    local output = ""
    if(handleFunc) then 
        if(req.method == "OPTIONS") then -- preflight call - return ok

            utils.sendpreflight( res )
            output = nil
        else 
            output = handleFunc( client, req, res, body ); handled = true 
        end 
    end 
    return handled, output
end

---------------------------------------------------------------------------------

local function processRequest(req, res, body)

    if( req.url == nil ) then 
        utils.sendhtml(res, "")
        return
    end

    local tcp = req.socket._handle
    local client = uv.tcp_getpeername( tcp )

    -- Api calls always first. These fan out - when a game starts then it handles its sockets
    if( string.match(req.url, "^/api/v1/") ) then 
        local handled, outjson = handleAPIEndpoints(client, req, res, body)
        if(outjson) then utils.sendjson(res, outjson) end
        return -- Always exit with api calls
    end

    -- Resource endpoints like images and similar
    if( handleEndpointMatch(client, req, res, body) ) then return end

    -- force login if its stale
    if( wui.invalidUser(client, tcpserve, req, res, body) ) then return end

    -- Web page endpoints (admin generally)
    if( handleEndpoints(client, req, res, body) ) then return end

    -- Umhandled always returns to login.
    wui.loginPage(client, req, res, body)
end

---------------------------------------------------------------------------------

local qs = require('querystring');

function onRequest(req, res) 
   
	local body = '';
	--req.setEncoding('utf8');
	req:on('data', function(chunk) body =body.. chunk end);
	req:on('end', function()
		local obj = qs.parse(body)
		processRequest(req, res, body)
	end);
end


local function run(port)

    ---------------------------------------------------------------------------------
    -- Need to auto update keys from lets encrypt
    local key = fs.readFileSync("./keys/privkey.pem")
    local cert = fs.readFileSync("./keys/fullchain.pem")

    ---------------------------------------------------------------------------------

    https.createServer({ key = key,  cert = cert, }, onRequest):listen(port)
    p("Server listening at https://"..SERVER_IP..":"..port.."/")

    -- Need to catch sig and close (for proper shutdown)
    --tcpserve.close()
    ---------------------------------------------------------------------------------

    tcpserve.runModules()

    print("Started...")
end

---------------------------------------------------------------------------------

return {
    run     = run,
}