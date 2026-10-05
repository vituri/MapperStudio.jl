# Validation of MapperStudio 0.1.0

## English interface and organization transfer — 5 October 2026

The application now uses English for static and dynamic interface text,
accessibility labels, demo headers/categories, CLI help, Julia errors,
scientific notes, exports and the complete research page. Canonical links point
to `JuliaTDA/MapperStudio.jl`.

On Linux with Julia 1.12.5, all **262 package assertions** passed again.
The browser suites passed **37 checks**: 28 workflow checks and nine gesture,
asynchronous-import and hidden-graph checks. Rebuilding while the Mapper tab is
hidden retains finite SVG coordinates. No invalid-coordinate console errors
remained after that correction.

Additional browser checks covered the English language declarations and views,
the English research page, and reopening a previous-format workspace containing
Portuguese headers, a Portuguese group name and its original color selection.
User-supplied data, names and settings were retained. The exported Julia analysis
script reproduced the browser model exactly for configuration, preprocessing,
lenses, PCA projection, node memberships/aggregates and edges.

Desktop, dark, mobile, Explain and persistence screenshots were refreshed in
English. `node --check web/app.js` passed, and the HTML control IDs, values and
structure were checked against the previous version.

## Standalone distribution — 4 October 2026

Under Julia 1.12.5 on Linux x86-64, the extracted app passed **262 assertions**
with `Pkg.test()`: the 250 scientific/API checks below plus 12 CLI checks.
Dependencies resolved from public Git revisions. The bundled multiparameter
scientific source was checked byte-for-byte against the workspace version,
and the included diabetes CSV matched its recorded SHA256.

`Pkg.Apps.add(path=...)` installed the committed Git repository into a separate
depot containing only the General registry, using cached public dependencies.
From an unrelated working directory, the installed launcher passed help,
version and invalid-port checks; served health, interface assets and research;
loaded the bundled 145-row dataset; and calculated a circle Mapper through REST
with full coverage. SIGINT closed the server through its exit hook without an
unhandled scheduler exception. `node --check web/app.js` also passed.

The repository's CI additionally exercises package tests and app launcher
installation on Linux, macOS and Windows. Platform-specific results should be
read from the [CI runs](https://github.com/JuliaTDA/MapperStudio.jl/actions/workflows/CI.yml).
The browser evidence below belongs to the original integrated app; the
standalone extraction changes packaging, branding, CLI and resource locations.

## Original integrated app — 3 October 2026

Executed on Linux x86-64. Scientific/API tests passed under
**Julia 1.12.5 and Julia 1.10.10**. Browser checks used Playwright with
HeadlessChrome 154, with the real Julia server running on port 8090.
These checks establish the tested behavior below; they do not establish
enterprise scalability or numerical equivalence with Ayasdi's proprietary code.

## Scientific and API references

The [test suite](../test/runtests.jl) passed **250 assertions on each Julia version**.

| Area | Assertions | Reference or behavior checked |
|---|---:|---|
| Data and preprocessing | 25 | Original missing values retained, median audit, scaling, invalid input rejection, real 145-row diabetes example |
| Gain/equalization | 77 | Analytic overlap `1−1/g`, full interval coverage, endpoints, constant coordinate and tied ranks |
| Mapper | 40 | Exact-circle graph has one component/one cycle, nerve edges independently reconstructed from shared row IDs, Jaccard thresholds, every refiner, seeded K-means, Ball coverage and DBSCAN singleton noise |
| Lenses/geometry | 43 | Five dissimilarities, finite values for all thirteen lens choices, Euclidean MDS distance reconstruction, deterministic landmark selection |
| Explain | 17 | Three SciPy `ks_2samp` statistic fixtures including ties, explicit BH reference, separated/constant features, seeded permutations, deduplication and disjoint comparison populations |
| Persistence/advanced TDA | 33 | Unit-circle Rips H1 persistence >1.5, final Betti numbers, zero-distance duplicates, ToMATo coverage, temporal source indices, Hilbert endpoint, analytic cubical annulus and all image filtrations |
| REST | 15 | Health, assets/research, CSP, import, model calculation, missing resources, invalid arguments, local origins/hosts and deduplicated CSV export |

The annulus fixture has exactly one H1 interval born at 0 and dying at 1;
its Euler characteristic changes from 0 to 1. The circle Mapper edges are
checked against a separate set-intersection construction, not a saved picture.

The 1.10 run used a fresh environment resolving the local packages and
`Pkg.test("MapperStudio")`. This avoids reusing a Manifest resolved for 1.12.
The production setup script also completed successfully with strict precompilation.

## Browser workflows

[browser-check.js](../scripts/browser-check.js) passed **28 checks**:
real Mapper and numeric colors; valid form submission; keyboard/pointer/linked
scatter selection; safe named groups and categorical text; Julia Explain and
exports; persistence, Betti curves and entropy summaries; cover sensitivity and saved configurations;
ToMATo; sliding-window PH; multiparameter Hilbert grid; image annulus PH;
original-data search; workspace data/group/configuration restoration; CSV
imputation; preservation of a usable model after an invalid configuration;
mobile configuration/laboratory layouts; and no JavaScript page errors.

[browser-interactions.js](../scripts/browser-interactions.js) passed **8 further
checks**: node movement without accidental selection, background pan, zoom,
rectangle selection of all 600 original rows without duplicates, rapid dataset
changes, a deliberately delayed CSV response, and clearing an old graph when
a different table fails scientific reconstruction.

Both files are async functions accepting a Playwright `page` fixture, against
a running local Studio. They are separate from the scientific test suite.
Expected HTTP 422 responses are intentionally exercised; they are not server
crashes. Main browser exports are written to `/tmp/mapper-studio-validation`.

Desktop **1440×1000**, persistence **1440×1500**, and mobile **390×844** layouts were inspected visually.
The mobile Mapper and laboratory checks found no horizontal document overflow.
Views preserve the main graph, population controls, local data and visible
scientific limits. Captures are retained here:

- [Light interface](screenshots/desktop.png)
- [Dark interface](screenshots/dark.png)
- [Mobile interface](screenshots/mobile.png)
- [Explain distributions](screenshots/explain.png)
- [Persistence diagram, barcode and Betti curves](screenshots/persistence.png)

## Export and documentation round trips

The browser-exported analysis script was executed in Julia. On the 600-row
example, its result matched the browser's model **exactly** for configuration,
preprocessing, lenses, PCA projection, node memberships, aggregates, edges and
graph invariants. UUIDs and wall-clock duration are intentionally run-specific.

A second exported script used headers containing `$` and quotes, and cells
containing backslashes and a Julia-interpolation-looking string. It ran as
literal CSV data, with the same scientific result as the browser. The graph
JSON contains no DOM element properties, and the standalone SVG parsed as XML.

`node --check web/app.js` passed. The parent JuliaTDA Documenter build completed
and included the Studio page. Existing large example outputs used Documenter's
PNG fallback as reported by its non-fatal rendering warning. Nothing was deployed.

## Remaining validation and scope

There is no million-row, sparse-matrix, distributed, multiuser or production
availability benchmark. Source rows are bounded at 3,000; Rips calculations
use explicit landmark limits. Sampling, scaling, covers and manual population
selection can alter conclusions. Explain's BH adjustment does not correct
selection bias. The graph's cycle rank is distinct from point-cloud PH.

This release covers the workflows in the [feature matrix](ayasdi-research.md).
Proprietary Neighborhood lenses, enterprise collaboration, supervised ensembles,
and automatic guarantees of an optimal model remain outside the implementation.
