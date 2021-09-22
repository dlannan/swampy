<div class="panel panel-default">
    <div class="panel-heading main-bgcolors">
    <h3 class="panel-title">Game User Profiles</h3>
    </div>
    <div class="panel-body">
    <table class="table table-striped table-hover">
    {{if data then}}
        <tr>
        {{for k,v in pairs(data.header) do}}
        <th>{{= v}}</th>
        {{end}}
        </tr>
        {{for k,v in pairs(data.rows) do}}
        <tr>
            {{for kk,vv in pairs(data.header) do}}
        <td>{{= v[vv]}}</td>
            {{end}}
        {{end}}
        </tr>
        {{end}}
    </table>
    </div>
</div>

