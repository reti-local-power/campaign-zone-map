// This script contains all the jQuery listeners used on this website


//// Create clickable menu of layers

// 1. assign actions to clicking one button (onClick())
// 2. actions should be to change multiple layers' visibility simultaneously (set.LayoutProperty)

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
    document.getElementById("my-sidepanel").style.width = "30%";
  
  }
  
  /* Set the width of the sidebar to 0 (hide it) */
  function closeNav() {
    document.getElementById("my-sidepanel").style.width = "0";
  
  }
  
  