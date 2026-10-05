"""
    SignedMeasure(locations, weights)

A finite signed atomic measure, with atoms as **columns** of a 2×n matrix and
one real weight per atom. Locations and weights must be finite and are stored
as `Float64`. Negative weights and repeated locations are permitted; weights
need not sum to one. An empty measure uses `zeros(2,0)` and `Float64[]`.

See [`signed_measure`](@ref) for construction from invariant grids or exact
Euler grades, and [`MeasureVectorizer`](@ref) for fixed-length numerical features.
"""
struct SignedMeasure
    locations::Matrix{Float64}
    weights::Vector{Float64}
    function SignedMeasure(locations, weights)
        P, w = Matrix{Float64}(locations), collect(Float64, weights)
        size(P) == (2, length(w)) || throw(ArgumentError("expected a 2×n atom matrix"))
        all(isfinite, P) && all(isfinite, w) || throw(ArgumentError("finite atoms and weights required"))
        new(P, w)
    end
end

"""
    signed_measure(G::GridInvariant)

Möbius (mixed finite-difference) measure of a Hilbert or Euler grid. Its cumulative
sum reconstructs `G.values` exactly, taking values below the grid to be zero.
No artificial death is added at the upper boundary: the grid extends constantly.
Raw atomic measures and bigraded Betti arrays need not be stable in an unweighted
norm. Stability claims require a chosen measure distance and bounded total variation.
"""
function signed_measure(G::GridInvariant)
    atoms = NTuple{2,Float64}[]; weights = Float64[]
    v(i,j) = i < 1 || j < 1 ? 0 : G.values[i,j]
    for j in eachindex(G.levels), i in eachindex(G.scales)
        w = v(i,j) - v(i-1,j) - v(i,j-1) + v(i-1,j-1)
        if !iszero(w)
            push!(atoms, (G.scales[i],G.levels[j])); push!(weights,w)
        end
    end
    P = isempty(atoms) ? zeros(2,0) : reduce(hcat, collect.(atoms))
    return SignedMeasure(P, weights)
end

"""
    signed_measure(F::Bifiltration)

Exact Euler measure, with mass (-1)^dimension at each simplex's actual grade.
Its quadrant cumulative sum is the Euler surface without snapping grades to a
sampling grid. For fixed simplex combinatorics, Gaussian vectorization is
Lipschitz under matched grade perturbations, with total variation bounded by the
number of simplices. Changing a truncation cutoff can change the combinatorics
and is outside this bound. Use `signed_measure(hilbert_function(...))` instead
for the grid's homology Hilbert measure, whose stability has different conditions.
"""
function signed_measure(F::Bifiltration)
    P=isempty(F.grades) ? zeros(2,0) : reduce(hcat,collect.(F.grades))
    return SignedMeasure(P,[isodd(length(s)) ? 1.0 : -1.0 for s in F.simplices])
end

"""
    MeasureVectorizer(centers; bandwidth=1.0)

Fixed Gaussian test-function features of a signed measure. Centers are a 2×m matrix;
outputs always have length m. For matched atoms, moving atoms by δ changes each
feature by at most `sum(abs, weights)*δ/(bandwidth*sqrt(exp(1)))`. This is a
bounded-Lipschitz measure vectorization; it does not assert interleaving stability
of an arbitrary homology Hilbert measure. Shared centers must be fitted on training
data only. See `measure_vectorizer_model` for an optional MLJ adapter.
"""
struct MeasureVectorizer
    centers::Matrix{Float64}
    bandwidth::Float64
    function MeasureVectorizer(centers; bandwidth=1.0)
        P = Matrix{Float64}(centers)
        size(P,1) == 2 && size(P,2)>0 && all(isfinite,P) || throw(ArgumentError("finite 2×m centers required"))
        isfinite(bandwidth) && bandwidth>0 || throw(ArgumentError("bandwidth must be positive"))
        new(P,Float64(bandwidth))
    end
end
function (v::MeasureVectorizer)(m::SignedMeasure)
    return [sum(w * exp(-sum(abs2, p .- c)/(2v.bandwidth^2))
                for (p,w) in zip(eachcol(m.locations),m.weights); init=0.0)
            for c in eachcol(v.centers)]
end

"""
    measure_vectorizer_model(; bandwidth=1.0, resolution=(10,10), centers=nothing)

Create an optional MLJ signed-measure transformer. Install and load
`MLJModelInterface` (or `MLJBase`) to activate the extension before calling it.
Input is a vector of [`SignedMeasure`](@ref)s or a Tables.jl table with a
`measure` column. Output is a Tables-compatible named tuple of continuous
feature columns `measure_1`, `measure_2`, etc., with one row per measure.

`fit` learns a rectangular grid of `prod(resolution)` Gaussian centers from
training atom ranges unless a finite 2×m `centers` matrix is supplied. Constant
ranges are widened by ±0.5; all-empty training atoms use [-1,1] on each axis.
`bandwidth` must be finite and positive, and both resolution entries positive
integers. `transform` reuses the fitted [`MeasureVectorizer`](@ref); held-out
atom ranges never update it. Fit centers inside each cross-validation training
fold to avoid leaking held-out information. The model learns a representation,
not a classifier or a statistical calibration.
"""
function measure_vectorizer_model end
