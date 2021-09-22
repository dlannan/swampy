<script>

function createTable( data )
{
    var tabletext = "<table class='table table-striped table-hover'>";

    for( row in data ) {
        var rowtext = "<tr class='module-row'>";
        var rowdata = data[row];
        for( key in rowdata ) {
            rowtext = rowtext + "<td>" + rowdata[key] + "</td>";
        }
        rowtext = rowtext + "</tr>";
        tabletext = tabletext + rowtext;
    }
    $(".module-table").append(tabletext + "</table>");
}

$(document).ready(function(){
    $(".module-row").click(function(){

        var modname = $(this).attr("data-name");
        $("#game-module-detail").text(modname);

        $.ajax({
            dataType: "json",
            url: "/api/moduledata.json",
            data: { "name": modname },
            success: function( data ) {
                
                $(".module-tabs ul").html("");
                for( tname in data) {
                    var tab = "<li><a href='#' class='tab-btn'>" + tname + "</a></li>";
                    $(".module-tabs ul").append( tab );
                }
                $(".tab-btn").click( function(e) {
                    $(".module-table").html("");
                    createTable( data[$(e.target).text()]);
                });
            }
        });

        var moddata = ""
        //console.log(moddata);
        //$(".module-data").text( moddata );
    });
});
</script>