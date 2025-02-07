function show_label(x,y,deg,text) {
  const degrees_to_radians = deg => (deg * Math.PI) / 180.0;

  let clone = $('svg',document.querySelector('#label').content.cloneNode(true));
  $('text',clone).text(text);
  let n = $('body').append(clone);
  let dim = $('text',clone)[0].getBBox();
  let height = $('rect',clone).attr('height');
  let width = dim.width + dim.x;
  let shift = (width + 10) * Math.sin(degrees_to_radians(deg));
  let shift_plus = height * Math.sin(degrees_to_radians(90-deg));
  let neigh = (width + 10) * Math.cos(degrees_to_radians(deg)) + height * Math.cos(degrees_to_radians(90-deg));

  let top_y = 23 * Math.cos(degrees_to_radians(deg));
  let top_x = 23 * Math.sin(degrees_to_radians(deg));

  $(clone).css('left',x-top_x);
  $(clone).css('top',y-shift-top_y);

  $(clone).attr('height',shift + shift_plus + 2);
  $(clone).attr('width',neigh + 2);
  $('g',clone).attr('transform',$('g',clone).attr('transform').replace(/%%1/, shift + 1).replace(/%%2/, deg));
  $('rect',clone).attr('width',width);
}

function show_row_label(data) {
  let pos = data.getBoundingClientRect();
  let pos_top = $('#graphcolumn')[0].getBoundingClientRect();
  let pos_y;
  let text = $('text',data).text();
  if (pos.y < (pos_top.y + 10)) {
    pos_y = pos_top.y + 10;
  } else {
    pos_y = pos.y;
  }
  show_label(pos.x + 12, pos_y, 60, text);
}

$(document).ready(function() {
  var current_label;
  $('#graphgrid').on('mouseout','svg .resource-column, svg .resource-point',(data)=>{
    $('.displaylabel').remove();
    current_label = undefined;
  });
  $('#graphcolumn').scroll((data)=>{
    if (current_label != undefined) {
      $('.displaylabel').remove();
      show_row_label(current_label);
    }
  });
  $('#graphgrid').on('mouseover','svg .resource-column',(data)=>{
    show_row_label(data.target);
    current_label = data.target;
  });
  $('#graphgrid').on('mouseover','svg .resource-point',(ev)=>{
    let rc = $(ev.target).attr('resource-column');
    let data = $('.resource-column[resource-column=' + rc + ']')[0];
    show_row_label(data);
    current_label = data;
    // let pos = data.target.getBoundingClientRect();
    // let text = $('text',data.target).text();
    // show_label(pos.x + 12, pos.y + 5, 60, text);
  });
});
