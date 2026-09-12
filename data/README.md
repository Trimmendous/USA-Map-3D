# Free state boundaries

`us_states.json` bundles all 50 states as named lists of separate latitude/
longitude rings. It is normalized boundary data, not a GeoJSON FeatureCollection.
The renderer requires no downloads or MATLAB toolbox datasets.

- 49 states: [PublicaMundi / MappingAPI US state geometry](https://github.com/PublicaMundi/MappingAPI/blob/master/data/geojson/us-states.json).
- Alaska: [Glynn Bird's US states geometry](https://github.com/glynnbird/usstatesgeojson/blob/master/alaska.geojson),
  which credits [Eric Celeste's US Census boundary conversions](https://eric.clst.org/tech/usgeojson/).
  Celeste identifies the underlying Census geography as public-domain US government data.

Only state names and coordinates are retained; population/density attributes
are not used. Alaska's rings were simplified with Douglas–Peucker tolerance
0.025 degrees; rings that would collapse below three vertices were retained
unsimplified. All 81 Alaska parts are preserved. The complete dataset has
143 parts and 5,848 coordinate pairs, including ring-closing points.

These generalized shapes are for visualization, not surveying. Source detail
varies, particularly between Alaska and the other states. Alaska and Hawaii
are repositioned and rescaled as labeled insets during rendering; the stored
coordinates remain geographic. Counts come only from `banklist.csv`.
