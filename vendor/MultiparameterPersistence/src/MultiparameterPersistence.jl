"""Exact finite-grid, two-parameter persistence over F₂ for small simplicial complexes."""
module MultiparameterPersistence

using LinearAlgebra
using Tables

export Bifiltration, bifiltration, GridInvariant, hilbert_function,
    euler_surface, bigraded_betti, SignedMeasure, signed_measure,
    MeasureVectorizer, measure_vectorizer_model

include("bifiltration.jl")
include("linear_algebra.jl")
include("invariants.jl")
include("measures.jl")

end
