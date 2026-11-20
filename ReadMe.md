# USA 3D Map

A MATLAB-language visualization of bank failures by US state. Runs in **GNU
Octave for free**, or MATLAB, using bundled state geometry. All application and
rendering code is in `.m` files.

Repository: [Trimmendous/USA-Map-3D](https://github.com/Trimmendous/USA-Map-3D).

![USA bank failures](output/usa-bank-failures.png)

## Installation

Install GNU Octave, then open this project folder in Octave. The default map
runs offline and needs no add-on packages. MATLAB R2016b or newer can also read
the bundled JSON; no Financial or Mapping Toolbox is needed for the default map.

The mapping package is only needed if you choose to load a separate shapefile.

## Usage

```matlab
usa                                         % bank-failure demo
usa(data)                                   % your data
usa(data, 'Title', 'Median income', 'Output', 'out.png')
```

`data` can be almost anything keyed by state. Keys may be postal codes or
names in any case (`'CA'`, `'california'`, `'New_York'`):

```matlab
usa(struct('CA', 39.0, 'TX', 30.5, 'NY', 19.6))          % scalar struct
usa(containers.Map({'CA','New York'}, {3, 7}))           % Map
usa({{'CA','NY','TX'}, [3 7 2]})                         % keys + values
usa(myTable, 'StateColumn', 'st', 'ValueColumn', 'pop')  % table / struct array
usa({'CA','CA','TX'})                                    % raw records: counted
usa(values50)                                            % 50-vector, alphabetical (see usaStates)
usa('sales.csv', 'ValueColumn', 'Revenue')               % CSV: summed per state
usa('banklist.csv')                                      % CSV, no value column: rows counted
```

Repeated keys are combined with `'Aggregate'` (`sum`, `count`, `mean`, `max`,
`min`). Non-state keys such as `PR` or `DC` are skipped with one warning.
`usaData` does the normalization on its own if you only want the 50x1 vector.

| Option | Default | |
|---|---|---|
| `Title`, `ValueLabel`, `Footer` | | Text |
| `Output` | `''` | Write a PNG (figure closes unless returned) |
| `Colors` | `'value'` | `'value'` ramp, `'states'` distinct palette, N x 3 colormap, or colormap name |
| `Height` | `0.35` | Tallest prism as a fraction of map width |
| `Contours` | `0` | Stacked rings: N levels, or `'unit'` for one per 1.0 |
| `View` | `[-12 55]` | Azimuth, elevation |
| `Legend` | `true` | `false`, or N for the top N states |
| `Format` | `'%g'` | Legend number format |
| `Renderer` | `'auto'` | `'opengl'` rotatable, `'raster'` fixed image |
| `Boundaries` | bundled | Alternate `.json` or shapefile |

From a terminal:

```bash
octave --no-gui --quiet --eval "usa([], 'output/usa-bank-failures.png')"
```

## Performance

The 2.5D look is built to be cheap:

- Polygons are triangulated once (~1.5 s), then cached in memory and in
  `tempdir` (~0.06 s to reload). The cache is keyed on the boundary file.
- The whole map is **one patch** (tops plus walls) and one outline line per
  state: about 50 graphics objects instead of one per contour ring. The
  original version created ~1,500, so rotation now stays smooth.
- Walls get a fake directional shade computed once per edge, so no lighting
  engine runs.
- In Octave 11 (qt), the demo renders and saves in ~0.5 s, down from ~5.2 s.

If only gnuplot is available, `rasterizeMap` draws the same scene with a
depth buffer into a fixed image (~1.8 s); rotation isn't available there.

To load a shapefile with a `Name` field, use `usa(data, 'Boundaries',
'/path/to/states.shp')`. Keep the matching `.shx` and `.dbf` files alongside
it. This needs Octave's mapping package or MATLAB's Mapping Toolbox, and
polygon holes are not supported.

## Map and data

- The demo keeps the original alphabetical state colors and one-contour-per-failure style.
- All 50 states are included. Alaska and Hawaii are labeled, rescaled insets.
- Heights represent counts; zero-count states remain flat and gray.
- The bundled CSV has **563 records in the 50 states** (2000 to July 2023).
  Four Puerto Rico records are excluded because the map covers the 50 states.
- Quoted CSV fields containing commas are supported.
- Coordinates use a spherical Lambert conformal conic projection with standard
  parallels 33/45 degrees and mainland origin 39/-96 degrees.

## Boundary handling

The original implementation manually split MATLAB's `usastatelo` coordinate
lists to keep islands and separate land areas from being joined. The replacement
dataset explicitly records those separate areas, so the renderer now reads each
ring independently. Triangulation fills concave coastlines; a depth buffer hides
surfaces behind nearer states in the fixed-view export.

See [data/README.md](data/README.md) for source links and simplification details.
These are generalized visualization boundaries.

## Validation

```matlab
addpath('tests');
test_map
```

Checks cover state coverage, triangulated polygon areas, every data-adapter
input form, and draw-order-independent depth buffering. MATLAB execution still needs verification;
development checks run in GNU Octave 11.1.

## Future

- Add US territories, including Puerto Rico and Guam.

## Contributing

Contributions are welcome. This project started as an experiment in MATLAB
mapping and 3D visualization.

## License

The application is under the MIT License; see [LICENSE](LICENSE).
Boundary provenance is documented separately in [data/README.md](data/README.md).
