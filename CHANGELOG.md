# Changelog

## Unreleased — 5 October 2026

- Translate the interface, accessibility labels, CLI help, Julia errors,
  scientific notes, research page, demo data and export filenames to English.
- Transfer the repository to `JuliaTDA/MapperStudio.jl` and update canonical links.
- Preserve existing workspace data, names and settings when reopening files.
- Avoid invalid SVG coordinates when rebuilding a graph while its tab is hidden.

## 0.1.0 — 4 October 2026

- Extract MapperStudio from `JuliaTDA.jl/apps/MapperStudio` into its own repository.
- Install with Julia 1.12's `app add` and launch with `mapperstudio`.
- Add CLI help, version and validated port options.
- Resolve JuliaTDA dependencies from pinned public Git revisions.
- Bundle the Reaven–Miller example and the MIT multiparameter reference module.
- Include scientific/API tests and app installation CI for Linux, macOS and Windows.
