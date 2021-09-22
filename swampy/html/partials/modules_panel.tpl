<div class="panel panel-default">
    <div class="panel-heading main-bgcolors">

        <h3 class="panel-title">Game Modules</h3>
    
        <div class="dropdown module-edit">
            <button class="btn btn-default dropdown-toggle" type="button" id="dropdownMenu1" data-toggle="dropdown" aria-haspopup="true" aria-expanded="true">
            Module Menu
            <span class="caret"></span>
            </button>
            <ul class="dropdown-menu" aria-labelledby="dropdownMenu1">
            <li data-toggle="modal" data-target="#addPage"><a href="#">Create</a></li>
            <li><a href="#">Modify</a></li>
            <li><a href="#">Delete</a></li>
            </ul>
        </div>

    </div>
    <div class="panel-body game-modules">
    <table class="table table-striped table-hover">
    {{if data and table.getn(data) > 0 then}}
        <tr>
        {{for k,v in pairs(header) do}}
        <td>{{= v}}</td>
        {{end}}
        </tr>
        {{for i,module in ipairs(data) do}}
        <tr id="module-row-{{= i}}" data-name="{{= module[1]}}" class="module-row">
            {{for col,v in pairs(module) do}}
            {{if col == "uptime" then }}
            {{local ts = string.format(v, "%05d secs")}}
        <td>{{= ts}}</td>
            {{else}}
        <td>{{= v}}</td>
            {{end}}
            {{end}}
        {{end}}
        </tr>
        {{end}}
    </table>
    </div>
</div>
<div class="panel panel-default">
    <div class="panel-heading main-bgcolors">

        <h3 id="game-module-detail" class="panel-title">&nbsp</h3>

    </div>

    <div class="panel-body game-module-detail">
        <div class="module-data">
            <div class="module-tabs">
                <ul id="module-tables" class="nav nav-tabs">
                </ul>
            </div>
            <div class="module-table">
            <div>
        </div>
    </div>
</div>
