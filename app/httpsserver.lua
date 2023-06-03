
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

local cfg       = require("app.server-config")
require('lua.pretty-print')
local dbg       = require('lua.debugger')

-- TODO Make this our sqlite server
local tcpserve  = require("app.dataserver")
local wui       = require("app.webinterface")

---------------------------------------------------------------------------------
-- Init before assignments
tcpserve.init(args)
wui.init(tcpserve)


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
    local font = fs.readFileSync("./admin/"..req.url)
    if font then 
        local ext = string.match(req.url, "%.(.*)$") or "ttf"
        local ctype = "font/"..ext
        utils.senddata( res, font, ctype)
    end
end

---------------------------------------------------------------------------------

local function getCSS(client, req, res) 

    -- TODO: Need to check with mime type really
    local css = fs.readFileSync("./admin/"..req.url)
    if css then utils.senddata( res, css, "text/css") end
end

---------------------------------------------------------------------------------

local function getJS(client, req, res) 

    -- TODO: Need to check with mime type really
    local js = fs.readFileSync("./admin/"..req.url)
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
    local img = fs.readFileSync("./admin/"..req.url)
    local ext = string.sub(req.url, -3, -1)
    --p("[Extension] ", ext)
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
    ['^/css/(.*)%.map$']    = function(client, req, res, body) notFound(res) end,

--    ['^/(.*)%.html$']       = getHTML,
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

local function processRequest(req, res, body)

    if( req.url == nil ) then 
        utils.sendhtml(res, "")
        return
    end

    local tcp = req.socket._handle
    local client = uv.tcp_getpeername( tcp )

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
	req:on('data', function(chunk) body = body..chunk end);
	req:on('end', function()
		local obj = qs.parse(body)
		processRequest(req, res, body)
	end);
end

---------------------------------------------------------------------------------

local function run(port)

    ---------------------------------------------------------------------------------
    -- Need to auto update keys from lets encrypt
    local key = fs.readFileSync(pathJoin("./keys", "privkey.pem"))
    local cert = fs.readFileSync(pathJoin("./keys", "fullchain.pem"))

    ---------------------------------------------------------------------------------
    https.createServer({ key = key, cert = cert }, onRequest):listen(port)
    p("Server listening at https://"..cfg.SERVER_IP..":"..port.."/")

    -- Need to catch sig and close (for proper shutdown)
    --tcpserve.close()
    ---------------------------------------------------------------------------------

    tcpserve.runModules( )

    print("Started server...")
end

---------------------------------------------------------------------------------

return {
    run     = run,
}
