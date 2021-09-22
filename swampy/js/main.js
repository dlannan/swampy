
$(document).ready(function(){
    $(".editableTd").on('click', function () {
        if ($(this).find('input').is(':focus')) return this;
        var cell = $(this);
        var content = $(this).html();
        $(this).html('<input type="text" value="' + $(this).html() + '" />')
            .find('input')
            .trigger('focus')
            .on({
                'blur': function () {
                    $(this).trigger('closeEditable');
                },
                'keyup': function (e) {
                    if (e.which == '13') { // enter
                        $(this).trigger('saveEditable');
                    } else if (e.which == '27') { // escape
                        $(this).trigger('closeEditable');
                    }
                },
                'closeEditable': function () {
                    cell.html(content);
                    console.log(content);
                    $.getJSON("/api/adminupdate?username=" + content +"&", function(e) {
                        console.log(e);
                    });
                },
                'saveEditable': function () {
                    content = $(this).val();
                    $(this).trigger('closeEditable');
                }
            });
    });
});
