// TO-DO LIST
// - Add street view to buildings info-panel using Camille's code as an example: https://github.com/cpreeldumas/final-project/blob/main/js/scripts.js#L279

// Setting up MapBox
ACCESS_TOKEN = 'pk.eyJ1IjoiaGVucnkta2FuZW5naXNlciIsImEiOiJjbHVsdTU1Z20waG84MnFwbzQybmozMjdrIn0.tqmZ-jfP2M6xcOz09ckRPA';

mapboxgl.accessToken = ACCESS_TOKEN;

var mapOptions = {
  container: 'my-map-container', // container ID
  style: 'mapbox://styles/mapbox/light-v11', // light basemap
  center: [-74.00711, 40.67589], // starting position [lng, lat]
  zoom: 13, // starting zoom,
}

// Construct the map
const map = new mapboxgl.Map(mapOptions);

// add a navitation control
const nav = new mapboxgl.NavigationControl();
map.addControl(nav, 'top-right');

// add search bar to search addresses in NYC
const searchJS = document.getElementById('search-js');
searchJS.onload = function () {
    const searchBox = new MapboxSearchBox();
    searchBox.accessToken = ACCESS_TOKEN;
    searchBox.options = {
        types: 'address,poi',
        proximity: [-73.95841, 40.65259] // using a point in the center of Brooklyn
    };
    searchBox.marker = true;
    searchBox.mapboxgl = mapboxgl;
    map.addControl(searchBox, 'top-left');
};

// create zoom var where campaign zone fills disappear and the user can interact with buildings
var zoomswitch = 14;

// create polygon ID vars for cz and bldg (used later to toggle fill opacity and border color)
let clickedPolygonId = null
let clickedPolygonId2 = null


// add geojson layer for building information to the map
map.on('load', () => {

  // // Get list of all layers on the map, so we know where to insert the new layers
  // console.log(
  //   map.getStyle().layers
  // )

  //// Add geojson layers to the map ------------------------------------------
  // Add a data source containing GeoJSON data (NYC hole layer).
  map.addSource('nyc-hole', {
    'type': 'geojson',
    'data': 'data-prep/dat/for-web-map/nycblur.geojson'
  });

  // Add a new layer to visualize campaign zone areas (fill)
  map.addLayer({
    'id': 'nyc-hole-fill',
    'type': 'fill',
    'source': 'nyc-hole', // reference the data source read in above
    'layout': {},
    'paint': {
      'fill-color': '#ccc',
      'fill-opacity': 0.2
    }
  }, 'waterway-label');

  // Add a data source containing GeoJSON data (subscriber DAC maps).
  map.addSource('subscriber', {
    'type': 'geojson',
    'data': 'data-prep/dat/for-web-map/subscriber_nyc.geojson'
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
    'data': 'data-prep/dat/for-web-map/nyc_bldg.geojson',
    'generateId': true // this will add an id to each feature, this is necessary if we want to use featureState (see below)
  });

  // Add a new layer to visualize building information
  map.addLayer({
    'id': 'bldg-fill',
    'type': 'fill',
    'source': 'bldg', // reference the data source read in above
    'layout': {},
    'paint': {
      'fill-color': [
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

  // Add a hidden version of this to toggle with the publicly owned button
  map.addLayer({
    'id': 'bldg-line-public',
    'type': 'line',
    'source': 'bldg', // reference the data source read in above
    'layout': {},
    'paint': {
      'line-color': '#179f3b',
      'line-width': 1.5,
      'line-opacity': [
        'interpolate',
        ['linear'],
        ['get', 'pub_own'],
        // colors mirror the static maps created for the report
        0,
        0,
        1,
        1
      ]
    }
  }, 'waterway-label');

    // Set this layer to not be visible initially so it can be turned on using the botton
    map.setLayoutProperty('bldg-line-public', 'visibility', 'none');
  
 // Add a data source containing GeoJSON data (existing RETI community solar projects).
 map.addSource('reti', {
  'type': 'geojson',
  'data': 'data-prep/dat/for-web-map/nyc_reti.geojson',
  'generateId': true // this will add an id to each feature, this is necessary if we want to use featureState (see below)
});

  // indicate RETI projects with a line when zoomed in
  //  this is introduced here so the black hover border for buildings sits over this layer
  map.addLayer({
    'id': 'reti-line',
    'type': 'line',
    'source': 'reti', // reference the data source read in above
    'minzoom': zoomswitch, // hide line once the user zooms out enough (set by var earlier on)
    'layout': {},
    'paint': {
      'line-color': '#f57b00',
    }
  }, 'waterway-label');

  // Add a new layer for hovering over building information (line)
  map.addLayer({
    'id': 'bldg-line-hover',
    'type': 'line',
    'source': 'bldg', // reference the data source read in above
    'layout': {},
    'paint': {
      'line-color': '#292929',
      'line-width': [
        'case',
        ['boolean', ['feature-state', 'hover'], false],
        1.5,  // opacity when hover is true
        0 // opacity when hover is false
      ]
    }
  }, 'waterway-label');

  // Add a new layer to visualize active building information (line)
  map.addLayer({
    'id': 'bldg-line',
    'type': 'line',
    'source': 'bldg', // reference the data source read in above
    'layout': {},
    'paint': {
      'line-color': '#f0410c',
      'line-width': [
        'case',
        ['boolean', ['feature-state', 'clicked'], false],
        2.5,  // opacity when clicked is true
        0 // opacity when hover is true
      ]
    }
  }, 'waterway-label');

  // Add a data source containing GeoJSON data (campaign zone).
  map.addSource('cz', {
    'type': 'geojson',
    'data': 'data-prep/dat/for-web-map/nyc_cz.geojson',
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
    'minzoom': zoomswitch, // replace fill with border line at zoom switch
    'layout': {},
    'paint': {
      'line-color': '#54278f',
      'line-width': 2,
      'line-opacity': 0.8
    }
  }, 'waterway-label');

  // Add a new layer to visualize RETI projects (fill)
  //  This works at small zooms, and is replaced by a line type layer at larger zooms
  map.addLayer({
    'id': 'reti-fill',
    'type': 'fill',
    'source': 'reti', // reference the data source read in above
    'maxzoom': zoomswitch, // hide fill once the user zooms in enough (set by var earlier on)
    'layout': {},
    'paint': {
      'fill-color': '#f57b00',
    }
  }, 'waterway-label');


  // Set this layer to not be visible initially so it can be turned on using the botton
  map.setLayoutProperty('reti-fill', 'visibility', 'none');
  map.setLayoutProperty('reti-line', 'visibility', 'none');

  // Add a data source containing GeoJSON data (industrial business zones).
  map.addSource('ibz', {
    'type': 'geojson',
    'data': 'data-prep/dat/for-web-map/nyc_ibz.geojson',
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
    'data': 'data-prep/dat/for-web-map/nyc_bid.geojson',
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


  // Add a data source containing GeoJSON data (Community Districts).
  map.addSource('cd', {
    'type': 'geojson',
    'data': 'data-prep/dat/for-web-map/nyc_cd.geojson',
    'generateId': true // this will add an id to each feature, this is necessary if we want to use featureState (see below)
  });

  // Add a new layer to visualize bid borders (fill)
  map.addLayer({
    'id': 'cd-fill',
    'type': 'fill',
    'source': 'cd', // reference the data source read in above
    'maxzoom': zoomswitch, // hide fill once the user zooms in enough (set by var earlier on)
    'layout': {},
    'paint': {
      'fill-color': '#e4e4e4',
      'fill-opacity': [
        'case',
        ['boolean', ['feature-state', 'hover'], false],
        0.3, // opacity when hover is false
        0 // opacity when hover is true
      ]
    }
  }, 'waterway-label');

  // Add a new layer to visualize bid borders (line)
  map.addLayer({
    'id': 'cd-line',
    'type': 'line',
    'source': 'cd', // reference the data source read in above
    'layout': {},
    'paint': {
      'line-color': '#666666',
      'line-width': 2
    }
  }, 'waterway-label');

  // Set this layer to not be visible initially so it can be turned on using the botton
  map.setLayoutProperty('cd-line', 'visibility', 'none');
  map.setLayoutProperty('cd-fill', 'visibility', 'none');


  // Add a data source containing GeoJSON data (Community Districts).
  map.addSource('council', {
    'type': 'geojson',
    'data': 'data-prep/dat/for-web-map/nyc_council.geojson',
    'generateId': true // this will add an id to each feature, this is necessary if we want to use featureState (see below)
  });

  // Add a new layer to visualize bid borders (fill)
  map.addLayer({
    'id': 'council-fill',
    'type': 'fill',
    'source': 'council', // reference the data source read in above
    'maxzoom': zoomswitch, // hide fill once the user zooms in enough (set by var earlier on)
    'layout': {},
    'paint': {
      'fill-color': '#e4e4e4',
      'fill-opacity': [
        'case',
        ['boolean', ['feature-state', 'hover'], false],
        0.3, // opacity when hover is false
        0 // opacity when hover is true
      ]
    }
  }, 'waterway-label');

  // Add a new layer to visualize bid borders (line)
  map.addLayer({
    'id': 'council-line',
    'type': 'line',
    'source': 'council', // reference the data source read in above
    'layout': {},
    'paint': {
      'line-color': '#282828',
      'line-width': 2
    }
  }, 'waterway-label');

  // Set this layer to not be visible initially so it can be turned on using the botton
  map.setLayoutProperty('council-line', 'visibility', 'none');
  map.setLayoutProperty('council-fill', 'visibility', 'none');


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

  // Create id to keep track of which bldg the mouse is hovering over
  let hoveredPolygonIdbldg = null;

  // On zoom above value for cz fill to disappear Change mouse to pointer when on individual buildings (no hover state)
  //  and add black border to bldg to encourage clicking
  map.on('mousemove', 'bldg-fill', (e) => {

    // get the current zoom
    var curzoom = map.getZoom();

    // don't do anything if there are no features from this layer under the mouse pointer OR if zoom is too small
    if (e.features.length > 0 & curzoom >= zoomswitch) {
      // if hoveredPolygonId already has an id in it, set the featureState for that id to hover: false
      if (hoveredPolygonIdbldg !== null) {
        map.setFeatureState(
          { source: 'bldg', id: hoveredPolygonIdbldg },
          { hover: false }
        );
      }
      // make the cursor a pointer to let the user know it is clickable
      map.getCanvas().style.cursor = 'pointer'

      // set hoveredPolygonId to the id of the feature currently being hovered
      hoveredPolygonIdbldg = e.features[0].id;

      // set the featureState of this feature to hover:true
      map.setFeatureState(
        { source: 'bldg', id: hoveredPolygonIdbldg },
        { hover: true }
      );
    }
  });

  // resets the feature state to the default (nothing is hovered) when the mouse leaves the 'bldg-fill' layer
  map.on('mouseleave', 'bldg-fill', () => {

    // set the featureState of the previous hovered feature to hover:false
    if (hoveredPolygonIdbldg !== null) {
      map.setFeatureState(
        { source: 'bldg', id: hoveredPolygonIdbldg },
        { hover: false }
      );
    }
    // clear hoveredPolygonId
    hoveredPolygonIdbldg = null;
    // set the cursor back to default
    map.getCanvas().style.cursor = ''

  });

  //// Set up click to add information to the info-panel about campaign zones and buildings
  // if the user clicks the 'cz-fill' layer, extract properties from the clicked feature, using jQuery to write them to another part of the page.
  // NOTE: if statement makes this only happen when the zoom is smaller than the threshold level where the cz-fill disappears

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

      // remove bldg clicked featurestate if it is already set on another feature
      if (clickedPolygonId2 !== null) {
        map.setFeatureState(
          { source: 'bldg', id: clickedPolygonId2 },
          { clicked: false }
        )
      }

      // set the featureState of this feature to hover:true
      map.setFeatureState(
        { source: 'cz', id: clickedPolygonId },
        { clicked: true }
      )

      // hide info-panel-instructions
      $('#info-panel-instruction').css('z-index', -1);

      // get feature information from the items in the array e.features
      var campzone = e.features[0].properties.campzone
      var n = e.features[0].properties.n
      var elcprd = numeral(parseInt(e.features[0].properties.avg_energy_m_wh)).format('0,0')
      var score = numeral(e.features[0].properties.avg_suitability).format('0.0[0]')
      var size = numeral(e.features[0].properties.area).format('0.0[0]')

      // create HTML table describing the selected campaign zone
      const tableHTML = `
        <div>
          <b>Campaign Zone:<i> ${campzone} </i></b>
        </div>
        <p>
                
        <div style="border-radius: 10px; padding: 4px;">
            <table style="border-collapse: collapse; width: 100%">
                <tr>
                    <td style="width: 60%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;"><b>Number of buildings:</b></td>
                    <td style="width: 40%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;">${n}</td>
                </tr>
                <tr>
                    <td style="width: 60%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;"><b>Average solar energy potential:</b></td>
                    <td style="width: 40%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;">${elcprd} MWh/year</td>
                </tr>
                <tr>
                    <td style="width: 60%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;"><b>Average suitability score:</b></td>
                    <td style="width: 40%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;">${score} out of 14</td>
                </tr>
                <tr>
                    <td style="width: 60%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;"><b>Area:</b></td>
                    <td style="width: 40%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;">${size} square miles</td>
                </tr>
            </table>
        </div>

        <div style="font-size: smaller;">
          <a
        href="https://docs.google.com/spreadsheets/d/1y22m3agXjRcUbxfUBImUrFwhE-AeWXXA/edit?usp=sharing&ouid=113455286937839782442&rtpof=true&sd=true"
        target="_blank">More info about campaign zones</a>
        </div>
        `;

      // Update the info-panel with the table
      document.getElementById('info-panel-text').innerHTML = tableHTML;

      // Style info-panel to match the highlighted campaign zone
      $('#info-panel').css('opacity', '1');
      $('#info-panel').css('z-index', '1');
      $('#info-panel').css('width', '27.5%');
      $('#info-panel').css('transform', 'translate(0,0)');
      $('#info-panel').css('background-color', '#c4aae6');
      $('#info-panel').css('border-color', '#54278f');
      $('#info-panel').css('border-width', '3');
      $('#info-panel').css('border-style', 'dashed');
    }
  });

  // if the user clicks the 'bldg-fill' layer, extract properties from the clicked feature, using jQuery to write them to another part of the page.
  // NOTE: if statement makes this only happen when the zoom is larger than the threshold level where the cz-fill disappears

  map.on('click', 'bldg-fill', (e) => {
    var curzoom = map.getZoom(); // define curzoom as the current zoom when the click occurs

    // remove clicked featurestate if it is already set on another feature
    if (clickedPolygonId2 !== null) {
      map.setFeatureState(
        { source: 'bldg', id: clickedPolygonId2 },
        { clicked: false }
      )
    }

    if (curzoom >= zoomswitch) {

      clickedPolygonId2 = e.features[0].id;

      // remove clicked featurestate from cz if it is already set on another feature
      if (clickedPolygonId !== null) {
        map.setFeatureState(
          { source: 'cz', id: clickedPolygonId },
          { clicked: false }
        )
      }

      // set the featureState of this feature to clicked:true
      map.setFeatureState(
        { source: 'bldg', id: clickedPolygonId2 },
        { clicked: true }
      )

      // hide info-panel-instructions
      $('#info-panel-instruction').css('z-index', -1);


      // get feature information from the items in the array e.features
      var address = e.features[0].properties.address
      var score = parseInt(e.features[0].properties.index)
      var owner = e.features[0].properties.ownername
      var campzone = e.features[0].properties.campzone
      var elcprd = numeral(parseInt(e.features[0].properties.ElcPrdMwh)).format('0,0')

      // Extract longitude and latitude from the clicked feature
      const lng = e.features[0].properties.centroid_lon;
      const lat = e.features[0].properties.centroid_lat;

      // Construct the road view URL with the extracted coordinates
      const roadViewURL = `https://roadview.planninglabs.nyc/view/${lng}/${lat}`;

      // Construct the HTML for the road view element
      const roadViewHTML = `
        <div id="info-panel-streetview" class="road-view">
            <iframe src="${roadViewURL}" width="100%" height="200px"></iframe>
        </div>
        `;

      // create HTML table describing the selected building
      const tableHTML = `
        <div>
          <b>Building:<i> ${address} </i></b>
          <p>
          <button type="button" id="streetview-button" onclick=streetview()>See street view</button>
        </div>
        <p>

        <div id="bldg-table" style="border-radius: 10px; padding: 4px;">
            <table style="border-collapse: collapse; width: 100%">
              <tr>
                  <td style="width: 50%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;"><b>Suitability score:</b></td>
                  <td style="width: 50%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;">${score} out of 14</td>
              </tr>
              <tr>
                  <td style="width: 50%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;"><b>Owned by:</b></td>
                  <td style="width: 50%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;">${owner}</td>
              </tr>
              <tr>
                  <td style="width: 50%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;"><b>Annual solar energy potential:</b></td>
                  <td style="width: 50%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;">${elcprd} MWh/year</td>
              </tr>
              <tr>
                  <td style="width: 50%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;"><b>Campaign zone:</b></td>
                  <td style="width: 50%; border-bottom: 1px solid #292929; padding: 2px; font-size: smaller;">${campzone}</td>
              </tr>
            </table>
        </div>

        
        <div style="font-size: smaller;">
        <a
        href="https://docs.google.com/spreadsheets/d/1sKxq-GygRArKFFbTleWZxuNo5V-MnsqK/edit?usp=sharing&ouid=113455286937839782442&rtpof=true&sd=true"
        target="_blank">More info about suitable community solar buildings</a>
        </div>
        
        ${roadViewHTML} <!-- Add roadViewHTML here -->
        
        `;

      // Update the info-panel with the table
      document.getElementById('info-panel-text').innerHTML = tableHTML;

      // Style info-panel to match the highlighted building
      $('#info-panel').css('opacity', '1');
      $('#info-panel').css('z-index', '1');
      $('#info-panel').css('width', '27.5%');
      $('#info-panel').css('transform', 'translate(0,0)');
      $('#info-panel').css('background-color', '#c8dcf0');
      $('#info-panel').css('border-color', '#f0410c');
      $('#info-panel').css('border-width', '2');
      $('#info-panel').css('border-style', 'solid');
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

  //// Create gentle hover state for Community Districts (CD) to encourage clicks

  let hoveredPolygonId4 = null; // need to create a new ID var for each layer in question

  map.on('mousemove', 'cd-fill', (e) => {

    if (e.features.length > 0) {
      if (hoveredPolygonId4 !== null) {
        map.setFeatureState(
          { source: 'cd', id: hoveredPolygonId4 },
          { hover: false }
        );
      }
      hoveredPolygonId4 = e.features[0].id;
      map.setFeatureState(
        { source: 'cd', id: hoveredPolygonId4 },
        { hover: true }
      );
    }
  });

  // When the mouse leaves the cd-fill layer, update the feature state of the
  // previously hovered feature.
  map.on('mouseleave', 'cd-fill', () => {
    if (hoveredPolygonId4 !== null) {
      map.setFeatureState(
        { source: 'ibz', id: hoveredPolygonId4 },
        { hover: false }
      );
    }
    hoveredPolygonId4 = null;
  });

  //// Create pop-up name for CDs and BIDs on mouse click
  map.on('click', 'cd-fill', (e) => {
    cdnum = e.features[0].properties.boro_cd

    new mapboxgl.Popup()
      .setLngLat(e.lngLat)
      .setHTML('Community District: ' + cdnum)
      .addTo(map);
  });

  // Change the cursor to a pointer when
  // the mouse is over the states layer.
  map.on('mouseenter', 'cd-fill', () => {
    map.getCanvas().style.cursor = 'pointer';
  });

  // Change the cursor back to a pointer
  // when it leaves the states layer.
  map.on('mouseleave', 'cd-fill', () => {
    map.getCanvas().style.cursor = '';
  });

  //// Create gentle hover state for City Council Districts (council) to encourage clicks

  let hoveredPolygonId5 = null; // need to create a new ID var for each layer in question

  map.on('mousemove', 'council-fill', (e) => {

    if (e.features.length > 0) {
      if (hoveredPolygonId5 !== null) {
        map.setFeatureState(
          { source: 'council', id: hoveredPolygonId5 },
          { hover: false }
        );
      }
      hoveredPolygonId5 = e.features[0].id;
      map.setFeatureState(
        { source: 'council', id: hoveredPolygonId5 },
        { hover: true }
      );
    }
  });

  // When the mouse leaves the council-fill layer, update the feature state of the
  // previously hovered feature.
  map.on('mouseleave', 'council-fill', () => {
    if (hoveredPolygonId5 !== null) {
      map.setFeatureState(
        { source: 'ibz', id: hoveredPolygonId5 },
        { hover: false }
      );
    }
    hoveredPolygonId5 = null;
  });

  //// Create pop-up name for councils and BIDs on mouse click
  map.on('click', 'council-fill', (e) => {
    distnum = e.features[0].properties.coun_dist;

    new mapboxgl.Popup()
      .setLngLat(e.lngLat)
      .setHTML('Council District: ' + distnum)
      .addTo(map);
  });

  // Change the cursor to a pointer when
  // the mouse is over the states layer.
  map.on('mouseenter', 'council-fill', () => {
    map.getCanvas().style.cursor = 'pointer';
  });

  // Change the cursor back to a pointer
  // when it leaves the states layer.
  map.on('mouseleave', 'council-fill', () => {
    map.getCanvas().style.cursor = '';
  });






});
