<ul class="list-group">
    {{for index, data in pairs(pages) do}}
    {{if active == data.url then}}
    <a href="{{= data.url}}" class="list-group-item main-bgcolors">
    {{else}}
    <a href="{{= data.url}}" class="list-group-item">
    {{end}}
    <span class="glyphicon {{= data.icon}}"></span> {{= data.title}}
    <span class="badge">{{= data.count}}</span>
    </a>
    {{end}}
</ul>