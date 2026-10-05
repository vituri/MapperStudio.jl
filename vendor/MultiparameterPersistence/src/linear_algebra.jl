# All elimination is exact, with XOR arithmetic. Never infer F₂ ranks using SVD.
function _rref(A)
    R = Matrix{Bool}(A)
    pivots = Int[]
    row = 1
    for col in axes(R, 2)
        row > size(R, 1) && break
        offset = findfirst(identity, @view R[row:end, col])
        isnothing(offset) && continue
        pivot = row + offset - 1
        R[row, :], R[pivot, :] = copy(R[pivot, :]), copy(R[row, :])
        for i in axes(R, 1)
            i != row && R[i, col] && (R[i, :] .= xor.(R[i, :], R[row, :]))
        end
        push!(pivots, col)
        row += 1
    end
    return R, pivots
end
_rank(A) = length(last(_rref(A)))
_basis(A) = Matrix{Bool}(A[:, last(_rref(A))])

function _kernel(A)
    R, pivots = _rref(A)
    free = setdiff(collect(axes(A, 2)), pivots)
    Z = falses(size(A, 2), length(free))
    for (j, col) in enumerate(free)
        Z[col, j] = true
        for (i, p) in enumerate(pivots)
            Z[p, j] = R[i, col]
        end
    end
    return Matrix(Z)
end

function _coordinates(basis, vectors)
    n = size(basis, 2)
    R, pivots = _rref(hcat(basis, vectors))
    all(p -> p <= n, pivots) || error("inclusion did not map cycles into cycles")
    length(pivots) == n || error("homology coordinate basis is not independent")
    return Matrix{Bool}(R[1:n, (n + 1):end])
end

struct HomologySpace
    boundaries::Matrix{Bool}
    representatives::Matrix{Bool}
end
_dimension(H::HomologySpace) = size(H.representatives, 2)

function _boundary(F, d)
    rows = findall(s -> length(s) == d, F.simplices)
    cols = findall(s -> length(s) == d + 1, F.simplices)
    lookup = Dict(F.simplices[i] => j for (j, i) in enumerate(rows))
    B = falses(length(rows), length(cols))
    for (j, i) in enumerate(cols), face in _faces(F.simplices[i])
        B[lookup[face], j] = true
    end
    return Matrix(B), rows, cols
end

function _homology(F, dim, grade)
    down, _, cells = _boundary(F, dim)
    up, _, higher = _boundary(F, dim + 1)
    active = findall(j -> all(F.grades[cells[j]] .<= grade), eachindex(cells))
    coactive = findall(j -> all(F.grades[higher[j]] .<= grade), eachindex(higher))
    Z = falses(length(cells), length(active) - _rank(down[:, active]))
    Z[active, :] = _kernel(down[:, active])
    B = _basis(up[:, coactive])
    combined = hcat(B, Z)
    _, pivots = _rref(combined)
    hcols = [p for p in pivots if p > size(B, 2)]
    return HomologySpace(B, Matrix{Bool}(combined[:, hcols]))
end

function _inclusion(source::HomologySpace, target::HomologySpace)
    C = _coordinates(hcat(target.boundaries, target.representatives), source.representatives)
    return C[(size(target.boundaries, 2) + 1):end, :]
end
