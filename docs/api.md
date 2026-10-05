# REST API

Base URL: `http://localhost:8090`. JSON endpoints return application/json.
The service binds to 127.0.0.1 and accepts local Host headers. Browser origins
must match the local application. It is a local single-user service, not a
public production deployment. CSV export returns text/csv.

```bash
curl -s http://localhost:8090/api/health
curl -s -X POST http://localhost:8090/api/demo \
  -H 'Content-Type: application/json' -d '{"kind":"circle","n":200}'
```

Use the returned dataset `id` as `dataset_id`. IDs and landmark/member row
indices are distinct: row indices are 1-based positions in the original table.

| Method/path | JSON body / response |
|---|---|
| `GET /api/health` | Version, Julia version, row limit, status |
| `GET /api/catalog` | Default config and demo names |
| `POST /api/demo` | `{kind,n?,seed?}`; complete table and metadata |
| `POST /api/import` | `{csv,name?}`; complete table and metadata |
| `GET /api/datasets/:id` | Complete original table and metadata |
| `POST /api/mapper` | `{dataset_id,config?}`; nodes, edges, original memberships, PCA projection, config and audit |
| `POST /api/explain` | `{dataset_id,selected,reference?,permutations?,seed?}`; ranked tests/distributions/effects/q |
| `POST /api/persistence` | `{dataset_id,config?,selected?,sample?,dimension?,threshold?}`; bars, Betti, entropy, landmark IDs |
| `POST /api/sensitivity` | `{dataset_id,config?,resolutions?,gains?}`; classic Mapper graph summaries |
| `POST /api/clustering` | `{dataset_id,config?,k?,tau?}`; ToMATo labels, row groups, density and peaks |
| `POST /api/timeseries` | `{dataset_id,column,dimension?,delay?,window?,step?}`; sliding-window summaries and source indices |
| `POST /api/multiparameter` | `{dataset_id,config?,sample?,dimension?}`; finite-grid Hilbert/Euler and landmark IDs |
| `POST /api/image` | `{pixels,filtration?,cutoff?,invert?}`; cubical bars, Euler and filtration offset; dataset not required |
| `POST /api/export/rows` | `{dataset_id,selected?}`; deduplicated row CSV, all rows by default |

`config` keys are described in `src/data.jl`'s `DEFAULT_CONFIG`. Unsupported
metric, lens, cover and clustering choices are rejected. Unknown resources return 404; invalid scientific
arguments return 422; cross-origin writes/unknown hosts return 403. Unexpected
errors return 500 and details appear in the Julia terminal. The server never
accepts filesystem paths or code to evaluate. An input over 20 MB is rejected.

Examples:

```json
{
  "dataset_id": "returned-uuid",
  "config": {
    "columns": ["x", "y"],
    "scaling": "standard",
    "metric": "euclidean",
    "lens1": "column:x",
    "lens2": "none",
    "resolution": 10,
    "gain": 2,
    "cluster": "single",
    "radius": 0.25
  }
}
```

Fields containing scientific infinity use `null` (e.g. an unobserved death).
The API does not treat `null` death as a zero or a finite maximum. The browser
displays it as essential/censored. Missing original table values also use null.
