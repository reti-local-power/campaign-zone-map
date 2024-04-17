// TO-DO LIST
// - Make cz fill disappear at a high zoom level (start at a smaller zoom than that)
// - Toggle ibz, bid, and subscriber maps on and off
// - Add subscriber maps to legend
// - Clickable information for buildings and cz
// - Hover button name for ibz & bid

// Setting up MapBox
mapboxgl.accessToken = 'pk.eyJ1IjoiaGVucnkta2FuZW5naXNlciIsImEiOiJjbHVsdTU1Z20waG84MnFwbzQybmozMjdrIn0.tqmZ-jfP2M6xcOz09ckRPA';

var mapOptions = {
  container: 'my-map-container', // container ID
  style: 'mapbox://styles/mapbox/light-v11', // light basemap
  center: [-73.89988, 40.66606], // starting position [lng, lat]
  zoom: 13, // starting zoom,
}

// Construct the map
const map = new mapboxgl.Map(mapOptions);

// add a navitation control
const nav = new mapboxgl.NavigationControl();
map.addControl(nav, 'top-right');

// add geojson layer for building information to the map
map.on('load', () => {

  // Get list of all layers on the map, so we know where to insert the new layers
  console.log(
    map.getStyle().layers
  )

  // Add a data source containing GeoJSON data (subscriber DAC maps).
  map.addSource('subscriber', {
    'type': 'geojson',
    'data': 'dat/for-web-map/subscriber.geojson'
  });

  // Add a new layer to visualize campaign zone areas (fill)
  map.addLayer({
    'id': 'subscriber-fill',
    'type': 'fill',
    'source': 'subscriber', // reference the data source read in above
    'layout': {},
    'paint': {
      'fill-color': ['get', 'color'],
      'fill-opacity': 0.6
    }
  }, 'waterway-label');

  // Add a data source containing GeoJSON data (campaign zone).
  map.addSource('cz', {
    'type': 'geojson',
    'data': 'dat/for-web-map/cz.geojson'
  });

  // Add a new layer to visualize campaign zone areas (fill)
  map.addLayer({
    'id': 'cz-fill',
    'type': 'fill',
    'source': 'cz', // reference the data source read in above
    'layout': {},
    'paint': {
      'fill-color': '#54278f',
      'fill-opacity': 0.4
    }
  }, 'waterway-label');

  // Add a data source containing GeoJSON data (building info).
  map.addSource('bldg', {
    'type': 'geojson',
    'data': 'dat/for-web-map/bldg.geojson'
  });

  // Add a new layer to visualize building information
  map.addLayer({
    'id': 'bldg-fill',
    'type': 'fill',
    'source': 'bldg', // reference the data source read in above
    'layout': {},
    'paint': {
      'fill-color': [
        // create fill colors based on site suitability scores (var: index)
        'interpolate',
        ['linear'],
        ['get', 'index'],
        // colors mirror the static maps created for the report
        0,
        '#f7fbff',
        2.1,
        '#c8dcf0',
        5.1,
        '#73b2d8',
        8.1,
        '#2979b9',
        11.1,
        '#08306b',

      ],
      'fill-opacity': 1
    }
  }, 'waterway-label');

  // Add a new layer to visualize campaign zone areas borders (line)
  map.addLayer({
    'id': 'cz-line',
    'type': 'line',
    'source': 'cz', // reference the data source read in above
    'layout': {},
    'paint': {
      'line-color': '#54278f',
      'line-width': 4,
      'line-dasharray': [2, 1]
    }
  }, 'waterway-label');

  // Add a data source containing GeoJSON data (industrial business zones).
  map.addSource('ibz', {
    'type': 'geojson',
    'data': 'dat/for-web-map/ibz.geojson'
  });

  // Add a new layer to visualize ibz borders (fill)
  map.addLayer({
    'id': 'ibz-fill',
    'type': 'fill',
    'source': 'ibz', // reference the data source read in above
    'layout': {},
    'paint': {
      'fill-color': '#f5be71',
      'fill-opacity': 0.1
    }
  }, 'waterway-label');

  // Add a new layer to visualize ibz borders (line)
  map.addLayer({
    'id': 'ibz-line',
    'type': 'line',
    'source': 'ibz', // reference the data source read in above
    'layout': {},
    'paint': {
      'line-color': '#f5be71',
      'line-width': 2
    }
  }, 'waterway-label');

  // Add a data source containing GeoJSON data (business improvement districts).
  map.addSource('bid', {
    'type': 'geojson',
    'data': 'dat/for-web-map/bid.geojson'
  });

  // Add a new layer to visualize bid borders (fill)
  map.addLayer({
    'id': 'bid-fill',
    'type': 'fill',
    'source': 'bid', // reference the data source read in above
    'layout': {},
    'paint': {
      'fill-color': '#98f511',
      'fill-opacity': 0.1
    }
  }, 'waterway-label');

  // Add a new layer to visualize bid borders (line)
  map.addLayer({
    'id': 'bid-line',
    'type': 'line',
    'source': 'bid', // reference the data source read in above
    'layout': {},
    'paint': {
      'line-color': '#98f511',
      'line-width': 2
    }
  }, 'waterway-label');

});


// // loop over the cz-info array to make a marker for each record
// czdata.forEach(function (czrecord) {

//   var color

//   // use if statements to assign colors based on pizzaData.program
//   if (czrecord.cz_top === 1) {
//     color = '#54278f'
//   }
//   if (czrecord.cz_top === 0) {
//     color = '#ac8fd5'
//   }

//   // create a popup to attach to the marker
//   const popup = new mapboxgl.Popup({
//     offset: 24,
//     anchor: 'bottom',
//     className: "cz-popup"
//   }).setHTML(
//     `This is the <b>${czrecord.campzone} campaign zone</b>. 
//     <ul>
//     <li>There are <b>${czrecord.n}</b> suitable buildings within the zone. </li> 
//     <li>The average suitability score is <b>${czrecord.avg_suitability_round}</b> out of 14, 
//         and the average building has the potential to generate <b>${czrecord.avg_energy_MWh_round}</b>.</li>
//     </ul>`
//   );

//   // create a marker, set the coordinates, add the popup, add it to the map
//   new mapboxgl.Marker({
//     scale: 0.65,
//     color: color
//   })
//     .setLngLat([czrecord.lon, czrecord.lat])
//     .setPopup(popup)
//     .addTo(map);
// })


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


// $(".collapsible").click(function () {
//   $(".collapsible").css('background', '#679a67');
// });

// function expandContract() {
//   const el = document.getElementById("expand-contract")
//   el.classList.toggle('expanded')
//   el.classList.toggle('collapsed')
// }

// Add active class (highlight button) to the button that is currently clicked
// var header = document.getElementById("column-left");
// var btns = header.getElementsByClassName("collapsible");
// for (var i = 0; i < btns.length; i++) {
//   btns[i].addEventListener("click", function () {
//     var current = document.getElementsByClassName("active");
//     if (current.length > 0) {
//       current[0].className = current[0].className.replace(" active", "");
//     }
//     this.className += " active";
//   });
// }