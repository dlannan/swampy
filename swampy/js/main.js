
const tween1 = KUTE.fromTo('#blob10', { path: '#blob10' }, { path: '#blob20' }, { repeat: 999, duration: 3000, yoyo: true } ).start();
const tween2 = KUTE.fromTo('#blob11', { path: '#blob11' }, { path: '#blob21' }, { repeat: 999, duration: 3000, yoyo: true } ).start();
const tween3 = KUTE.fromTo('#blob12', { path: '#blob12' }, { path: '#blob22' }, { repeat: 999, duration: 3000, yoyo: true } ).start();
const tween4 = KUTE.fromTo('#blob13', { path: '#blob13' }, { path: '#blob23' }, { repeat: 999, duration: 3000, yoyo: true } ).start();
const tween5 = KUTE.fromTo('#blob14', { path: '#blob14' }, { path: '#blob24' }, { repeat: 999, duration: 3000, yoyo: true } ).start();


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
