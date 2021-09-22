<!-- Add Page Modal -->
<div class="modal fade" id="addPage" tabindex="-1" role="dialog" aria-labelledby="myModalLabel">
  <div class="modal-dialog" role="document">
    <div class="modal-content">
      <form class="" action="index.html" method="post">

        <div class="modal-header">
          <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
          <h4 class="modal-title" id="myModalLabel">Add Module</h4>
        </div>
        <div class="modal-body">

          <div class="form-group">
            <label for="pgTitle">Module Name</label>
            <input type="text" class="form-control" id="module-name" placeholder="MyGame">
          </div>
          <div class="form-group">
            <label>Module Script</label>
<div id="module-editor">
local mygamename        = "MyGame"

local MODULEDB_FILE     = "mygame.sqlite3"
local SQLITE_TABLES     = {
    ["gamedata"]      = { create = "desc TEXT, data TEXT" },
}

local mygame        = {}
local mygamesql     = {}

mygame.init         = function(module)
    mygamesql.prevconn = sqlapi.getConn()
    mygamesql.conn = sqlapi.init(MODULEDB_FILE, SQLITE_TABLES)
end 

local function runGameStep( game, frame, dt )
end 

mygame.run          = function( mod, frame, dt )

    for k, game in pairs(mod.data.games) do 
        if(game == nil) then 
            moduleError("Game Invalid: ", k) 
        else
            runGameStep( game, frame, dt )
        end
    end
end 

mygame.creategame   = function( uid, name )

    local mygameobject = {
        name        = "MyGame", 
        sqlname     = "TblGame"..mygamename,
        maxsize     = 4,
        people      = {},
        owner       = uid, 
        private     = true, 
        state       = "something",
    }
    -- Do something with mygameobject 
    return mygameobject
end 

mygame.updategame   =  function( uid, name , body )
    -- get this game assuming you stored it :) and then do something 
    local game = getGame( name )
    if(game == nil) then return nil end 
    -- Return some json to players for updates 
end 

-- Get the sqltables this game module uses - its for the admin and other
mygame.gettables    = function() 

    sqlapi.setConn(mygamesql.conn)
    local jsontbl = {}
    for k ,v in pairs(SQLITE_TABLES) do
        local tbl = sqlapi.getTable( k, tablelimit )
        jsontbl[k] = tbl
    end
    sqlapi.setConn(mygamesql.prevconn)
    return json.encode(jsontbl)
end 

return mygame
</div>
          </div>
          <div class="form-group">
            <label for="">
              <input type="checkbox" name="" id="module-published" value="">
              Published
            </label>
          </div>
          <div class="form-group">
            <label for="">Meta Tags:</label>
            <input type="text" class="form-control" id="module-meta-tags" placeholder="Add some tags">
            <p class="help-block">Tags to be able to search for your module.</p>
          </div>
          <div class="form-group">
            <label for="">Meta Description:</label>
            <input type="text" class="form-control" id="module-desc" placeholder="Add some description">
            <p class="help-block">A short one sentence description of your module.</p>
          </div>



        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
          <button type="submit" class="btn btn-primary main-bgcolors">Save changes</button>
        </div>

      </form>
    </div>
  </div>
</div>
