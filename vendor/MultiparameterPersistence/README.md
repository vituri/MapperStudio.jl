# Bundled MultiparameterPersistence reference implementation

This is the MIT-licensed implementation from the JuliaTDA workspace's
`JuliaTDA.jl/lib/MultiparameterPersistence`, copied on 4 October 2026.
The original copyright and license are retained in [LICENSE](LICENSE).

The module is included as `MapperStudio.MultiparameterPersistence`; it supplies
the small, exact function-Rips calculations in the laboratory. Bundling its
source makes app installation independent of an unpublished sibling package.
The scientific code is unchanged. Its `Tables` and `LinearAlgebra` dependencies
are declared in MapperStudio's project. Optional upstream MLJ extensions are
outside the app's scope and are not bundled.
