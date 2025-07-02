// Initialize the map
const map = L.map('map').setView([0, 0], 2); // Centered at (0,0) with zoom level 2

// Add a base layer
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  attribution: '&copy; OpenStreetMap contributors',
}).addTo(map);

// Get the 'file' parameter from the URL (e.g., ?file=your-data.geojson)
const params = new URLSearchParams(window.location.search);
const jobId = params.get('job_id') || 'dummy'; // fallback if no parameter is given
const fileNameBase = params.get('filebase') || 'units_gridded'
const geojsonFilename = fileNameBase+'-'+jobId+'.json';
console.log('Will display '+fileNameBase+' of job '+jobId);

// Load GeoJSON from local server
//fetch('download/out/units_gridded-236a1ca8-56bb-11f0-bf80-fa163e42fba0.json')
fetch('download/out/'+geojsonFilename)
  .then((response) => {
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    console.log("Data retrieved...")
    return response.json();
  })
  .then((geojsonData) => {
    console.log("Data retrieved...")
    const geojsonLayer = L.geoJSON(geojsonData, {
      onEachFeature: function (feature, layer) {
        if (feature.properties && feature.properties.name) {
          layer.bindPopup(`<strong>${feature.properties.name}</strong>`);
        }
      },
    }).addTo(map);
    map.fitBounds(geojsonLayer.getBounds());
  })
  .catch((error) => {
    console.error('Error loading the GeoJSON:', error);
  });
