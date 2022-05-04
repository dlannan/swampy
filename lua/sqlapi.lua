
local ffi   = require "ffi"

local tinsert   = table.insert

local uv    = require('uv')
local json  = require('lua.json')
local sql   = require "deps.sqlite3"
local timer = require "deps.timer"
local utils = require "lua.utils"

-- Sql connections
local sqlconns = {}
-- Current connection
local conn = nil

---------------------------------------------------------------------------------
-- Helper to run pcalled sqlite commands
local function run_exec( str, log )
    if( log == nil ) then p("[DB exec] "..tostring(str)) end
    local result = conn:exec( str )
    return result
end 

---------------------------------------------------------------------------------
-- This auto builds tables when making a new db. 
local function checkTable( tablename, schema )

    local checktblstr = "SELECT name FROM sqlite_master WHERE type='table' AND name='%s'"
    local status, result = pcall( run_exec, string.format(checktblstr, tablename) ) 
    -- Create table if false
    if(status == false or result == nil) then 
        local createstr = "CREATE TABLE "..tablename.."("..schema..")"
        status, result = pcall( run_exec, createstr )
        if(status == false) then 
            p("[Sqlite DB Error] Unable to create table: ", tablename, result)
        end
    end 
    return status, result
end

---------------------------------------------------------------------------------
-- This auto builds tables when making a new db. 
local function checkTables( tbls )

    for k,v in pairs( tbls ) do 
        checkTable(k, v.create)
    end
end

---------------------------------------------------------------------------------
local function init( filelabel, tbls )

    if(filelabel == nil) then return nil end
    local filename = "./data/"..filelabel..".sqlite3"
    p("[Sql file] ", filename)
    -- If filename is provided a new connection is made and set
    if(filename) then thisconn = sql.open(filename) end 
    if(thisconn == nil) then 
        p("[Sqlite DB Error] No conn set.")
        return nil, nil 
    end 

    tinsert(sqlconns, thisconn)
    conn = thisconn 
    checkTables( tbls )
    return thisconn  -- return the index. Use this to set conn
end

---------------------------------------------------------------------------------

local function setConn( connid )

    if(connid == nil) then return nil end
    for i,v in ipairs(sqlconns) do 
        if(connid == v) then conn = connid; return true end 
    end
    return nil
end

---------------------------------------------------------------------------------
-- Get the current conn index (for later use)
local function getConn()

    return conn
end 

---------------------------------------------------------------------------------
-- TABLES
---------------------------------------------------------------------------------

local function getTableColumns( tblname )
    if(tblname == nil) then 
        p("[Sql GetTableColumns Error] No table name provided.")
        return {}
    end 
    local sqlcmd = [[SELECT name, type FROM PRAGMA_TABLE_INFO(']]..tblname..[[');]]

    local tablenames = {}
    local tbl, rowcount = conn:exec(sqlcmd)
    if(rowcount == 0 or tbl == nil or tbl.name == nil) then 
        p("[Sql GetTableColumns Error] No names.")
        return tablenames
    end
    for k,v in ipairs(tbl.name) do
        tinsert(tablenames, { name = v, type = tbl.type[k] })
    end
    return tablenames
end 

---------------------------------------------------------------------------------

local function getTable( name, limit, where )

    if(name == nil) then 
        p("[Sql GetTable Error] No table name provided.")
        return {}
    end 

    local sqlcmd = [[SELECT * FROM ]]..name
    if(where) then sqlcmd = sqlcmd..[[ WHERE ]]..where end
    sqlcmd = sqlcmd..[[ ; ]]

    local jsontbl = {}
    local tbl, rowcount = conn:exec(sqlcmd)
    if(rowcount == 0 or tbl == nil) then 
        p("[Sql GetTable Error] No rows.")
        return {} 
    end

    local cols = tbl[0]
    for row = 1, rowcount do
        local addrow = {}
        for k, v in ipairs(cols) do addrow[v] = tbl[k][row] end 
        tinsert(jsontbl, addrow)  
    end 
    return jsontbl
end

---------------------------------------------------------------------------------

local function dropTable( tblname )
    local droptblstr = "DROP TABLE IF EXISTS '%s';"
    local status, result = pcall( run_exec, string.format(droptblstr, tblname) ) 
    if(status == false or result == nil) then 
        -- dont really care if it fails, it means the db is broken.
        p("[Sql database corrupt] Cannot drop table: ", tblname)
    end 
end

---------------------------------------------------------------------------------

local function setTable( name, data )

    local stmt = conn:prepare([[INSERT OR REPLACE INTO ]]..name..[[ VALUES(?, ?);]])
    local tbldata = json.decode(data)
    if(tbldata == nil) then return nil end
    
    local results = {}
    for k,v in pairs(tbldata) do

        local desc = v.desc
        local theme = v.theme or "zombie"
        stmt:reset()
        stmt:bind(desc, theme)
        stmt:step()
        tinsert(results, "OK:"..k)
    end
    stmt:close()
    return results
end

---------------------------------------------------------------------------------

local function setTableRow( tblname, rowdata )

    local cols = utils.tcount(rowdata)
    local sqlcmd = [[INSERT OR REPLACE INTO ]]..tblname..[[ VALUES(]]..string.rep("?,", cols-1)..[[?);]]
    local stmt = conn:prepare(sqlcmd)
    if(rowdata == nil) then return nil end
    
    local results = {}
    stmt:reset()
    for i,v in ipairs(rowdata) do stmt:bind1(i, v) end
    stmt:step()
    stmt:close()
    tinsert(results, "OK")
    return results
end 

---------------------------------------------------------------------------------

local function insertTableRow( tblname, rowdata )

    local cols = utils.tcount(rowdata)
    local cmd = [[INSERT INTO ]]..tblname..[[ VALUES(]]..string.rep("?,", cols-1)..[[ ?);]]
    local stmt = conn:prepare(cmd)
    
    if(rowdata == nil) then return nil end   
    local results = {}
    stmt:reset()
    for i,v in ipairs(rowdata) do 
        stmt:bind1(i, v) 
    end
    stmt:step()
    stmt:close()
    tinsert(results, "OK")
    return results
end 
---------------------------------------------------------------------------------

local function setTableValue( tblname, selcol, rowid, col, value )

    local sqlcmd = [[UPDATE ]]..tblname..[[ SET ]]..col..[[=']]..value..[[' WHERE ]]..selcol..[[=']]..rowid..[[';]]
    local status, result = pcall( run_exec, sqlcmd, true ) 
    if(status == false) then 
        p("[Sqlite DB Error] Unable to set table value: ", result)
    end
    return result
end 

---------------------------------------------------------------------------------

local function setModuleInfo( info )

    local tinfo = { 
        info.name, 
        info.dataread, 
        info.datawrite, 
        math.floor(info.lastupdate), 
        info.gamecount, 
        math.floor(info.uptime), 
        info.usercount, 
        info.activity,
    }
    -- Assign new info values to the row of the same name
    setTableRow( "TblModuleStats", tinfo )
end

---------------------------------------------------------------------------------
-- IMPORT
---------------------------------------------------------------------------------

local function importJSON( jsondata )

    if(type(jsondata) ~= "string") then return nil end 

    local jsontbl = json.decode(jsondata)
    -- Iterate expected format. 
    --   Array of objects, each object with a dbname, and data, Some data having multiple properties.
    for idx, dbobj in pairs(jsontbl) do 
        if(dbobj.dbname and dbobj.data) then 

            for k,v in pairs(dbobj.data) do
                local rowdata = { v.desc, v.theme }
                insertTableRow(dbobj.dbname, rowdata )
            end
        end 
    end
    return jsontbl
end 

---------------------------------------------------------------------------------

local function importJSONFile( jsonfile )

    local fh = io.open(jsonfile, "r");
    local jsondata = fh:read("*a")
    fh:close()
    return importJSON(jsondata)
end

---------------------------------------------------------------------------------

return {
    init            = init,
    setConn         = setConn, 
    getConn         = getConn,
    run_exec        = run_exec,

    dropTable       = dropTable,
    checkTable      = checkTable, 
    checkTables     = checkTables,
    getTableColumns = getTableColumns,
    getTable        = getTable,
    setTable        = setTable,
    setTableValue   = setTableValue,

    setModuleInfo   = setModuleInfo,

    importJSONFile  = importJSONFile,
    importJSON      = importJSON,
}

---------------------------------------------------------------------------------
