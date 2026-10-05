"""
    Bifiltration(simplices, grades)

A finite, downward-closed simplicial complex with grades `(scale, function)`.
Vertex labels are positive integers. Every face must occur and have a componentwise
smaller or equal grade. Coefficients throughout this package are F₂.

Supply one finite two-coordinate grade per nonempty simplex. The constructor
sorts vertex labels, rejects duplicate simplices/repeated vertices, and orders
the stored complex by simplex dimension and vertex labels. `F.simplices[i]`
and `F.grades[i]` refer to the same simplex. A simplex is active at `(r,a)`
when both grade coordinates are at most those thresholds.
"""
struct Bifiltration
    simplices::Vector{Tuple{Vararg{Int}}}
    grades::Vector{NTuple{2,Float64}}
    function Bifiltration(simplices, grades)
        ss = Tuple{Vararg{Int}}[Tuple(sort!(collect(Int, s))) for s in simplices]
        gg = NTuple{2,Float64}[(Float64(g[1]), Float64(g[2])) for g in grades]
        length(ss) == length(gg) || throw(ArgumentError("one grade per simplex is required"))
        all(s -> !isempty(s) && all(>(0), s) && allunique(s), ss) ||
            throw(ArgumentError("simplices must have distinct positive vertex labels"))
        allunique(ss) || throw(ArgumentError("duplicate simplices"))
        all(g -> all(isfinite, g), gg) || throw(ArgumentError("grades must be finite"))
        lookup = Dict(s => g for (s, g) in zip(ss, gg))
        for (s, g) in zip(ss, gg), face in _faces(s)
            haskey(lookup, face) || throw(ArgumentError("missing face $face"))
            all(lookup[face] .<= g) || throw(ArgumentError("face $face is born after $s"))
        end
        order = sortperm(ss; by=s -> (length(s), s))
        new(ss[order], gg[order])
    end
end

_faces(s) = length(s) == 1 ? Tuple{Vararg{Int}}[] :
    [Tuple(s[j] for j in eachindex(s) if j != i) for i in eachindex(s)]

"""
    bifiltration(points, values; dim_max=1, max_scale=Inf, max_simplices=20_000)

Function-Rips bifiltration: the grade of a simplex is its maximum pairwise
Euclidean distance and maximum vertex function value. `points` are a vector of
coordinate vectors (or a matrix with points in columns). Enumerates through
dimension `dim_max + 1`, including the boundaries needed for H`dim_max`.
`max_scale` truncates the Rips complex. Enumeration is exponential: the explicit
size limit prevents accidentally requesting a large dense research computation.

`values` contains one finite function value per point. Matrix input uses **points
in columns**; vector input uses equally sized finite coordinate vectors. Scale
is an edge-length threshold with no factor of two; vertices have scale grade 0.
Function levels may be negative. Returns a [`Bifiltration`](@ref).

The constructor includes all simplices of size at most `dim_max+2` whose maximum
edge length is at most `max_scale`. `dim_max` must be nonnegative, `max_scale`
nonnegative (possibly `Inf`), and `max_simplices` at least the vertex count.
Euler invariants concern this actual dimension-truncated complex, including the
extra chain dimension, rather than a full Rips complex in all dimensions.
"""
function bifiltration(points, values; dim_max::Integer=1, max_scale=Inf,
        max_simplices::Integer=20_000)
    X = points isa AbstractMatrix ? collect(eachcol(points)) : collect(points)
    n = length(X)
    n > 0 || throw(ArgumentError("points must be nonempty"))
    length(values) == n || throw(ArgumentError("one function value per point"))
    dim_max >= 0 || throw(ArgumentError("dim_max must be nonnegative"))
    max_scale >= 0 && !isnan(max_scale) || throw(ArgumentError("invalid max_scale"))
    max_simplices >= n || throw(ArgumentError("max_simplices is smaller than vertex count"))
    d = length(first(X))
    d > 0 && all(x -> length(x) == d && all(isfinite, x), X) ||
        throw(ArgumentError("finite, equally sized coordinate vectors required"))
    all(isfinite, values) || throw(ArgumentError("function values must be finite"))
    D = [sqrt(sum(abs2, X[i] .- X[j])) for i in 1:n, j in 1:n]
    ss = Tuple{Vararg{Int}}[]
    gg = NTuple{2,Float64}[]
    function visit(s::Vector{Int}, scale::Float64, level::Float64)
        push!(ss, Tuple(s)); push!(gg, (scale, level))
        length(ss) <= max_simplices || throw(ArgumentError("max_simplices exceeded; lower max_scale or dim_max"))
        length(s) >= dim_max + 2 && return
        for j in (last(s) + 1):n
            r = max(scale, maximum(D[i, j] for i in s))
            r <= max_scale && visit(vcat(s, j), r, max(level, values[j]))
        end
    end
    for i in 1:n
        visit([i], 0.0, Float64(values[i]))
    end
    return Bifiltration(ss, gg)
end
