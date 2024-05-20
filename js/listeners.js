// This script contains all the jQuery listeners used on this website

// Turn on popovers
const popoverTriggerList = document.querySelectorAll('[data-bs-toggle="popover"]')
const popoverList = [...popoverTriggerList].map(popoverTriggerEl => new bootstrap.Popover(popoverTriggerEl))


//// Create clickable menu of layers

// 1. assign actions to clicking one button (onClick())
// 2. actions should be to change multiple layers' visibility simultaneously (set.LayoutProperty)

$('#reti-button').on('click', function () {

  $(this).toggleClass("active");

  const currentvisibility = map.getLayoutProperty(
    'reti-line',
    'visibility'
  );

  if (currentvisibility === 'none') {
    map.setLayoutProperty('reti-line', 'visibility', 'visible');
    map.setLayoutProperty('reti-fill', 'visibility', 'visible');
  } else {
    map.setLayoutProperty('reti-line', 'visibility', 'none');
    map.setLayoutProperty('reti-fill', 'visibility', 'none');
  }


})

$('#bid-button').on('click', function () {

  $(this).toggleClass("active");

  const currentvisibility = map.getLayoutProperty(
    'bid-line',
    'visibility'
  );

  if (currentvisibility === 'none') {
    map.setLayoutProperty('bid-line', 'visibility', 'visible');
    map.setLayoutProperty('bid-fill', 'visibility', 'visible');
  } else {
    map.setLayoutProperty('bid-line', 'visibility', 'none');
    map.setLayoutProperty('bid-fill', 'visibility', 'none');
  }


})

$('#ibz-button').on('click', function () {

  $(this).toggleClass("active");

  const currentvisibility = map.getLayoutProperty(
    'ibz-line',
    'visibility'
  );

  if (currentvisibility === 'none') {
    map.setLayoutProperty('ibz-line', 'visibility', 'visible');
    map.setLayoutProperty('ibz-fill', 'visibility', 'visible');
  } else {
    map.setLayoutProperty('ibz-line', 'visibility', 'none');
    map.setLayoutProperty('ibz-fill', 'visibility', 'none');
  }
})

$('#dac-button').on('click', function () {

  $(this).toggleClass("active");

  const currentvisibility = map.getLayoutProperty(
    'dac-fill',
    'visibility'
  );

  if (currentvisibility === 'none') {
    map.setLayoutProperty('dac-fill', 'visibility', 'visible');
  } else {
    map.setLayoutProperty('dac-fill', 'visibility', 'none');
  }
})


$('#cd-button').on('click', function () {

  $(this).toggleClass("active");

  const currentvisibility = map.getLayoutProperty(
    'cd-fill',
    'visibility'
  );

  if (currentvisibility === 'none') {
    map.setLayoutProperty('cd-line', 'visibility', 'visible');
    map.setLayoutProperty('cd-fill', 'visibility', 'visible');
  } else {
    map.setLayoutProperty('cd-line', 'visibility', 'none');
    map.setLayoutProperty('cd-fill', 'visibility', 'none');
  }
})

$('#council-button').on('click', function () {

  $(this).toggleClass("active");

  const currentvisibility = map.getLayoutProperty(
    'council-fill',
    'visibility'
  );

  if (currentvisibility === 'none') {
    map.setLayoutProperty('council-line', 'visibility', 'visible');
    map.setLayoutProperty('council-fill', 'visibility', 'visible');
  } else {
    map.setLayoutProperty('council-line', 'visibility', 'none');
    map.setLayoutProperty('council-fill', 'visibility', 'none');
  }
})


// Create collapsible set of buttons within the sidepanel
var coll = document.getElementsByClassName("collapsible");
var i;

for (i = 0; i < coll.length; i++) {
  coll[i].addEventListener("click", function () {
    this.classList.toggle("active");
    var content = this.nextElementSibling;
    if (content.style.display === "block") {
      content.style.display = "none";
    } else {
      content.style.display = "block";
    }
  });
}

// Script to collapse/open the side panel
/* Set the width of the sidebar to 30% (show it) */
function openNav() {
  $('#my-sidepanel').css('transform', 'translate(0px)');
}

/* Set the width of the sidebar to 0 (hide it) */
function closeNav() {
  $('#my-sidepanel').css('transform', 'translate(-100%)');
}

// Script to hide info-panel if the user no longer wants it open
function closeinfo() {
  $('#info-panel').css('z-index', '-1');
  
  map.setFeatureState(
    { source: 'cz', id: clickedPolygonId },
    { clicked: false }
  );

  map.setFeatureState(
    { source: 'bldg', id: clickedPolygonId2 },
    { clicked: false }
  );
  
}

// Script to expand bldg info panel to include the streetview i-frame
//  This is done by doubling the width of the info-panel div, halving the table width, and making the streetview non-transparent
function streetview() {
  $('#info-panel').css('width', '55%');
  $('#bldg-table').css('width', '50%');
  $('#info-panel-streetview').css('opacity', '1');
  $('#info-panel-streetview').css('z-index', '1');
  

}



