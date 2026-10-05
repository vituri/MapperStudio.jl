function checked_ids(ds, ids; allow_empty=false)
    all(i -> i isa Integer && 1<=i<=rowcount(ds), ids) || throw(ArgumentError("Invalid row index."))
    selected=sort!(unique(Int.(ids)))
    !allow_empty && isempty(selected) && throw(ArgumentError("Select at least one row."))
    selected
end

"""Two-sample Kolmogorov–Smirnov statistic, respecting repeated values."""
function ks_statistic(a,b)
    sa,sb=sort(a),sort(b); values=sort!(unique(vcat(sa,sb)))
    maximum(abs(searchsortedlast(sa,v)/length(sa)-searchsortedlast(sb,v)/length(sb)) for v in values)
end

function categorical_distance(a,b)
    levels=unique(vcat(a,b))
    0.5sum(abs(count(==(v),a)/length(a)-count(==(v),b)/length(b)) for v in levels)
end

"""Benjamini–Hochberg adjusted p-values in input order."""
function bh_adjust(ps)
    n=length(ps); n==0 && return Float64[]
    order=sortperm(ps); adjusted=zeros(n); q=1.0
    for k in n:-1:1
        i=order[k]; q=min(q,ps[i]*n/k); adjusted[i]=q
    end
    adjusted
end

function histogram_pair(a,b; numeric=true)
    if numeric
        lo,hi=extrema(vcat(a,b)); hi==lo && (hi=lo+1)
        bounds=collect(range(lo,hi;length=13))
        counts(v)=[count(x -> i==12 ? bounds[i]<=x<=bounds[i+1] : bounds[i]<=x<bounds[i+1],v)/length(v) for i in 1:12]
        return Dict("bounds"=>bounds,"selected"=>counts(a),"reference"=>counts(b))
    end
    levels=sort!(unique(vcat(a,b))); length(levels)>30 && (levels=sort(levels;by=v->-count(==(v),vcat(a,b)))[1:30])
    Dict("labels"=>levels,"selected"=>[count(==(v),a)/length(a) for v in levels],"reference"=>[count(==(v),b)/length(b) for v in levels])
end

"""
Rank differences between deduplicated, disjoint row groups. Seeded permutation
p-values support ties and categorical variables; BH controls the tested family
under its usual assumptions, not selection bias from exploring this same data.
"""
function explain(ds::Dataset, selected; reference=nothing, permutations=199, seed=2007)
    19<=permutations<=1999 || throw(ArgumentError("Use between 19 and 1999 permutations."))
    a_ids=checked_ids(ds,selected)
    b_ids=isnothing(reference) ? setdiff(1:rowcount(ds),a_ids) : setdiff(checked_ids(ds,reference),a_ids)
    length(a_ids)>=2 && length(b_ids)>=2 || throw(ArgumentError("Each group needs at least two distinct rows; the reference excludes the intersection."))
    rng=MersenneTwister(seed); results=Dict{String,Any}[]
    for c in ds.columns
        a=filter(!isnothing,ds.data[c][a_ids]); b=filter(!isnothing,ds.data[c][b_ids])
        length(a)>=2 && length(b)>=2 || continue
        numeric=c in ds.numeric
        test=numeric ? ks_statistic : categorical_distance
        score=test(a,b); pooled=vcat(a,b); na=length(a); extreme=0
        for _ in 1:permutations
            order=randperm(rng,length(pooled))
            score_perm=test(pooled[order[1:na]],pooled[order[na+1:end]])
            extreme += score_perm >= score-1e-12
        end
        effect=nothing
        if numeric
            sa,sb=std(a),std(b); pooledsd=sqrt(((length(a)-1)*sa^2+(length(b)-1)*sb^2)/(length(a)+length(b)-2))
            effect=pooledsd>eps(Float64) ? (mean(a)-mean(b))/pooledsd : nothing
        end
        push!(results,Dict("column"=>c,"type"=>numeric ? "numeric" : "categorical",
            "test"=>numeric ? "Permutation KS" : "Permutation total variation", "score"=>score,
            "p"=>(extreme+1)/(permutations+1),"effect"=>effect,"selected_n"=>length(a),"reference_n"=>length(b),
            "selected_mean"=>numeric ? mean(a) : nothing,"reference_mean"=>numeric ? mean(b) : nothing,
            "histogram"=>histogram_pair(a,b;numeric)))
    end
    qs=bh_adjust([r["p"] for r in results])
    for (r,q) in zip(results,qs); r["q"]=q; end
    sort!(results;by=r->(r["q"],-r["score"]))
    Dict("features"=>results,"selected_n"=>length(a_ids),"reference_n"=>length(b_ids),
        "permutations"=>permutations,"seed"=>seed,"min_p"=>1/(permutations+1),
        "note"=>"Exploratory: groups selected from the same dataset introduce selection bias. q is BH on the tested variables, without correcting that bias. Validate with independent data.")
end
