# JuliaTDA Studio: design and implementation

Research and implementation date: 3 October 2026.

## Product direction

A local scientific workbench: open data, construct Mapper, explore its shape,
select a population, explain its differences, and inspect persistent homology.
Julia owns the scientific calculations; a dependency-free browser client owns
interaction and presentation. Existing JuliaTDA packages remain the algorithms'
source of truth. The app has a separate environment and does not add HTTP or
browser dependencies to the umbrella package.

## Design pass and critique

The network itself is the main visual. An instrument-panel layout puts the
pipeline on the left, the large network and linked projection in the middle,
and the selected population on the right. Tabs open persistence, sensitivity,
data, and research without competing with the graph. Alignment is left-oriented.

Tokens: paper `#f7f9fc`, white `#ffffff`, ink `#20304a`, muted `#65748b`, ocean
`#156a82`, and violet `#7958b5`. Scientific color maps run from blue through
teal and amber to coral; groups also have names, counts, and outlines. Type is
the user's system sans-serif, with Georgia only for the app's wordmark. This
keeps the entire workbench usable offline, without downloading fonts.

Initial critique: a conventional analytics dashboard would hide the actual
shape under summary cards. Replace that arrangement with an expansive graph
canvas, compact graph invariants, and persistent lens/metric controls. Avoid
decorative gradients and card grids. Use small multiples only where comparing
parameters needs them. Include a light/dark switch, keyboard selection,
reduced-motion support, mobile panels, and exportable SVG.

## Delivery scope

- Classic Mapper in one/two lenses, Ball Mapper, multiple distance measures,
  preprocessing, numeric-column selection, covers, clustering, nerves.
- PCA, metric MDS, diffusion, eccentricity, density, norm and column lenses.
- Zoom, pan, drag, rectangle selection, keyboard node selection, layouts,
  color/aggregation/size controls, linked scatterplot and member table.
- Deduplicated saved row groups; selected-vs-rest or group-vs-group Explain,
  numeric KS and categorical total-variation tests using seeded permutations,
  effect sizes and Benjamini–Hochberg adjustment.
- Persistent homology of the selected metric on the original cloud, diagrams,
  barcodes, Betti curves and explicit landmark provenance; optional H2.
- Cover-parameter sensitivity, connected-component autogroups and hotspots;
  no unsupported claim of automatic model optimality.
- ToMATo, sliding-window PH and finite-grid function-Rips multiparameter view.
- CSV and workspace import/export, reproducible Julia scripts, graph JSON/SVG,
  health and documented REST APIs; synthetic and real diabetes examples.
- Scientific reference, API and browser tests; desktop/mobile visual review.

The first release is local and bounded: 3,000 rows, 80 numeric dimensions,
300 landmarks for H0/H1, 80 for H2 and 28 for dense multiparameter calculations.
Million-row execution, a multiuser permissions system, proprietary Neighborhood
lenses, supervised ensembles and the full differentiable/PH API in the GUI are
follow-up work. These boundaries must be visible in documentation and results.
