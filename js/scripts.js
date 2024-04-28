// TO-DO LIST
// - Change state of building and CZ on click (active state?)
// - Figure out how to format text that is sent to info-panel on click
// - Turn active state off for CZ when bldg is clicked (and vice versa)

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

// create zoom var where campaign zone fills disappear and the user can interact with buildings
var zoomswitch = 14;

// add geojson layer for building information to the map
map.on('load', () => {

  // // Get list of all layers on the map, so we know where to insert the new layers
  // console.log(
  //   map.getStyle().layers
  // )

  //// Add geojson layers to the map ------------------------------------------
  // Add a data source containing GeoJSON data (subscriber DAC maps).
  map.addSource('subscriber', {
    'type': 'geojson',
    'data': 'dat/for-web-map/subscriber.geojson'
  });

  // Add a new layer to visualize campaign zone areas (fill)
  map.addLayer({
    'id': 'dac-fill',
    'type': 'fill',
    'source': 'subscriber', // reference the data source read in above
    'layout': {},
    'paint': {
      'fill-color': ['get', 'color'],
      'fill-opacity': 0.6
    }
  }, 'waterway-label');

  // Set this layer to not be visible initially so it can be turned on using the botton
  map.setLayoutProperty('dac-fill', 'visibility', 'none');

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
        // 'case',
        // ['boolean', ['feature-state', 'clicked'], false],
        // #f0410c,  // fill when clicked is true
        // // create fill colors based on site suitability scores (var: index)
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
        '#08306b'

      ],
      'fill-opacity': 1
    }
  }, 'waterway-label');

  // Add a data source containing GeoJSON data (campaign zone).
  map.addSource('cz', {
    'type': 'geojson',
    'data': 'dat/for-web-map/cz.geojson',
    'generateId': true // this will add an id to each feature, this is necessary if we want to use featureState (see below)
  });

  // Add a new layer to visualize campaign zone areas (fill)
  map.addLayer({
    'id': 'cz-fill',
    'type': 'fill',
    'source': 'cz', // reference the data source read in above
    'maxzoom': zoomswitch, // hide fill once the user zooms in enough (set by var earlier on)
    'layout': {},
    'paint': {
      'fill-color': '#54278f',
      // use a case expression to set the opacity of a polygon based on featureState
      'fill-opacity': [
        'case',
        ['boolean', ['feature-state', 'clicked'], false],
        0.8,  // opacity when clicked is true
        ['boolean', ['feature-state', 'hover'], false],
        0.6, // opacity when hover is false
        0.4 // opacity when hover is true
      ]
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
    'data': 'dat/for-web-map/ibz.geojson',
    'generateId': true // this will add an id to each feature, this is necessary if we want to use featureState (see below)
  });

  // Add a new layer to visualize ibz borders (fill)
  map.addLayer({
    'id': 'ibz-fill',
    'type': 'fill',
    'source': 'ibz', // reference the data source read in above
    'maxzoom': zoomswitch + 1.5, // hide fill once the user zooms in enough (set by var earlier on)
    'layout': {},
    'paint': {
      'fill-color': '#f5be71',
      'fill-opacity': [
        'case',
        ['boolean', ['feature-state', 'hover'], false],
        0.3, // opacity when hover is false
        0.1 // opacity when hover is true
      ]
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

  // Set this layer to not be visible initially so it can be turned on using the botton
  map.setLayoutProperty('ibz-fill', 'visibility', 'none');
  map.setLayoutProperty('ibz-line', 'visibility', 'none');

  // Add a data source containing GeoJSON data (business improvement districts).
  map.addSource('bid', {
    'type': 'geojson',
    'data': 'dat/for-web-map/bid.geojson',
    'generateId': true // this will add an id to each feature, this is necessary if we want to use featureState (see below)
  });

  // Add a new layer to visualize bid borders (fill)
  map.addLayer({
    'id': 'bid-fill',
    'type': 'fill',
    'source': 'bid', // reference the data source read in above
    'maxzoom': zoomswitch + 1.5, // hide fill once the user zooms in enough (set by var earlier on)
    'layout': {},
    'paint': {
      'fill-color': '#98f511',
      'fill-opacity': [
        'case',
        ['boolean', ['feature-state', 'hover'], false],
        0.3, // opacity when hover is false
        0.1 // opacity when hover is true
      ]
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

  // Set this layer to not be visible initially so it can be turned on using the botton
  map.setLayoutProperty('bid-line', 'visibility', 'none');
  map.setLayoutProperty('bid-fill', 'visibility', 'none');


  //// Set up hover state for campaign zones ----------------------------------
  // this is a variable to store the id of the feature that is currently being hovered.
  let hoveredPolygonId = null;

  // whenever the mouse moves on the 'cz-fill' layer, we check the id of the feature it is on 
  //  top of, and set featureState for that feature.  The featureState we set is hover:true or hover:false
  map.on('mousemove', 'cz-fill', (e) => {
    // don't do anything if there are no features from this layer under the mouse pointer
    if (e.features.length > 0) {
      // if hoveredPolygonId already has an id in it, set the featureState for that id to hover: false
      if (hoveredPolygonId !== null) {
        map.setFeatureState(
          { source: 'cz', id: hoveredPolygonId },
          { hover: false }
        );
      }

      // set hoveredPolygonId to the id of the feature currently being hovered
      hoveredPolygonId = e.features[0].id;

      // set the featureState of this feature to hover:true
      map.setFeatureState(
        { source: 'cz', id: hoveredPolygonId },
        { hover: true }
      );

      // make the cursor a pointer to let the user know it is clickable
      map.getCanvas().style.cursor = 'pointer'

      // resets the feature state to the default (nothing is hovered) when the mouse leaves the 'borough-boundaries-fill' layer
      map.on('mouseleave', 'cz-fill', () => {
        // set the featureState of the previous hovered feature to hover:false
        if (hoveredPolygonId !== null) {
          map.setFeatureState(
            { source: 'cz', id: hoveredPolygonId },
            { hover: false }
          );
        }

        // clear hoveredPolygonId
        hoveredPolygonId = null;

        // set the cursor back to default
        map.getCanvas().style.cursor = ''
      });

    }
  });

  // On zoom above value for cz fill to disappear Change mouse to pointer when on individual buildings (no hover state)

  map.on('mousemove', 'bldg-fill', (e) => {
    // get the current zoom
    var curzoom = map.getZoom();

    // don't do anything if there are no features from this layer under the mouse pointer OR if zoom is too small
    if (e.features.length > 0 & curzoom >= zoomswitch) {

      // make the cursor a pointer to let the user know it is clickable
      map.getCanvas().style.cursor = 'pointer'
    }
  });
  
  // resets the feature state to the default (nothing is hovered) when the mouse leaves the 'bldg-fill' layer
  map.on('mouseleave', 'bldg-fill', () => {

    // set the cursor back to default
    map.getCanvas().style.cursor = ''
  });

  //// Set up click to add information to the info-panel about campaign zones and buildings
  // if the user clicks the 'cz-fill' layer, extract properties from the clicked feature, using jQuery to write them to another part of the page.
  // NOTE: if statement makes this only happen when the zoom is smaller than the threshold level where the cz-fill disappears
  let clickedPolygonId = null

  map.on('click', 'cz-fill', (e) => {
    var curzoom = map.getZoom(); // define curzoom as the current zoom when the click occurs

    // remove clicked featurestate if it is already set on another feature
    if (clickedPolygonId !== null) {
      map.setFeatureState(
        { source: 'cz', id: clickedPolygonId },
        { clicked: false }
      )
    }

    if (curzoom < zoomswitch) {
      clickedPolygonId = e.features[0].id;

      // set the featureState of this feature to hover:true
      map.setFeatureState(
        { source: 'cz', id: clickedPolygonId },
        { clicked: true }
      )

      // get feature information from the items in the array e.features
      var campzone = e.features[0].properties.campzone
      var n = e.features[0].properties.n
      var elcprd = parseInt(e.features[0].properties.avg_energy_MWh)
      var score = parseInt(e.features[0].properties.avg_suitability)

      // insert the information into the sidebar using jQuery
      $('#info-panel').text(
        `Campaign Zone: ${campzone}
      Number of buildings: ${n}
      Average solar energy potential: ${elcprd} MWh/year
      Average suitability score: ${score}`
      )

      $('#info-panel').css('background-color', '#c4aae6');
    }
  });

  // if the user clicks the 'bldg-fill' layer, extract properties from the clicked feature, using jQuery to write them to another part of the page.
  // NOTE: if statement makes this only happen when the zoom is larger than the threshold level where the cz-fill disappears
  map.on('click', 'bldg-fill', (e) => {
    var curzoom = map.getZoom(); // define curzoom as the current zoom when the click occurs

    if (curzoom >= zoomswitch) {
      // get feature information from the items in the array e.features
      var address = e.features[0].properties.address
      var score = parseInt(e.features[0].properties.index)
      var owner = e.features[0].properties.ownername
      var campzone = e.features[0].properties.campzone
      var elcprd = parseInt(e.features[0].properties.ElcPrdMwh)

      // insert the information into the sidebar using jQuery
      $('#info-panel').text(
        `Building: ${address}
      Suitability score: ${score} out of 14
      Owned by: ${owner}
      Annual solar energy potential: ${elcprd} MWh/year
      Campaign zone: ${campzone}`
      )
      $('#info-panel').css('background-color', '#c8dcf0');
    }
  });


  //// Create gentle hover state for IBZ to encourage clicks

  let hoveredPolygonId2 = null; // need to create a new ID var for each layer in question

  map.on('mousemove', 'ibz-fill', (e) => {

    if (e.features.length > 0) {
      if (hoveredPolygonId2 !== null) {
        map.setFeatureState(
          { source: 'ibz', id: hoveredPolygonId2 },
          { hover: false }
        );
      }
      hoveredPolygonId2 = e.features[0].id;
      map.setFeatureState(
        { source: 'ibz', id: hoveredPolygonId2 },
        { hover: true }
      );
    }
  });

  // When the mouse leaves the state-fill layer, update the feature state of the
  // previously hovered feature.
  map.on('mouseleave', 'ibz-fill', () => {
    if (hoveredPolygonId2 !== null) {
      map.setFeatureState(
        { source: 'ibz', id: hoveredPolygonId2 },
        { hover: false }
      );
    }
    hoveredPolygonId2 = null;
  });

  //// Create gentle hover state for BID to encourage clicks

  let hoveredPolygonId3 = null; // need to create a new ID var for each layer in question

  map.on('mousemove', 'bid-fill', (e) => {

    if (e.features.length > 0) {
      if (hoveredPolygonId3 !== null) {
        map.setFeatureState(
          { source: 'bid', id: hoveredPolygonId3 },
          { hover: false }
        );
      }
      hoveredPolygonId3 = e.features[0].id;
      map.setFeatureState(
        { source: 'bid', id: hoveredPolygonId3 },
        { hover: true }
      );
    }
  });

  // When the mouse leaves the state-fill layer, update the feature state of the
  // previously hovered feature.
  map.on('mouseleave', 'bid-fill', () => {
    if (hoveredPolygonId3 !== null) {
      map.setFeatureState(
        { source: 'bid', id: hoveredPolygonId3 },
        { hover: false }
      );
    }
    hoveredPolygonId3 = null;
  });


  //// Create pop-up name for IBZ and BIDs on mouse click
  map.on('click', 'ibz-fill', (e) => {
    new mapboxgl.Popup()
      .setLngLat(e.lngLat)
      .setHTML(e.features[0].properties.ibz_name)
      .addTo(map);
  });

  // Change the cursor to a pointer when
  // the mouse is over the states layer.
  map.on('mouseenter', 'ibz-fill', () => {
    map.getCanvas().style.cursor = 'pointer';
  });

  // Change the cursor back to a pointer
  // when it leaves the states layer.
  map.on('mouseleave', 'ibz-fill', () => {
    map.getCanvas().style.cursor = '';
  });

  map.on('click', 'bid-fill', (e) => {
    new mapboxgl.Popup()
      .setLngLat(e.lngLat)
      .setHTML(e.features[0].properties.bid_name)
      .addTo(map);
  });

  // Change the cursor to a pointer when
  // the mouse is over the states layer.
  map.on('mouseenter', 'bid-fill', () => {
    map.getCanvas().style.cursor = 'pointer';
  });

  // Change the cursor back to a pointer
  // when it leaves the states layer.
  map.on('mouseleave', 'bid-fill', () => {
    map.getCanvas().style.cursor = '';
  });








});
