$(document).ready(function() {
  $('#tabmodel').click(function(event){
    $('#model ui-behind button:nth-child(1)').addClass('hidden');
  });
  $('#tabdataelements').click(function(event){
    $('#model ui-behind button:nth-child(1)').removeClass('hidden');
  });

  $('#model ui-behind button:nth-child(1)').click(function(event){
    var but = $(document).find('#model ui-content ui-area:not(.inactive) button');
        but.click();
    var are = $(document).find('#model ui-content ui-area:not(.inactive)');
    var tab = $(document).find('#model ui-content ui-area:not(.inactive) .relaxngui_table');
        are.animate({ scrollTop: tab.height() }, "slow");
  });

  $("button[name=save]").click(function(){
    var def = new $.Deferred();
    def.done(function(name,testset) {
      $.ajax({
        url: $('body').attr('current-save'),
        type: 'PUT',
        body: testset.serializePrettyXML(),
        success: function() {

        },
        error: function() {
          alert('rrrrr');
        }
      });
    });
    get_testset(def);
  });
});
