"""Exact overlap fraction in the chosen lens coordinate: overlap = 1 - 1/gain."""
function cover_intervals(values, resolution, gain)
    lo, hi = extrema(values)
    if lo == hi
        return [MetricSpaces.Interval(lo,hi)]
    end
    overlap = 1-1/gain
    width = (hi-lo)/(resolution-(resolution-1)*overlap)
    step = width/gain
    [MetricSpaces.Interval(lo+(i-1)*step, i==resolution ? hi : lo+(i-1)*step+width) for i in 1:resolution]
end

function equalized(values)
    sorted = sort(values); n=length(values)
    [((searchsortedfirst(sorted,v)+searchsortedlast(sorted,v))/2-1)/(n-1) for v in values]
end

"""Deterministic farthest-point landmarks; returns original 1-based row IDs."""
function landmarks(d, count; seed=2007)
    n=size(d,1); count=min(count,n)
    selected=[rand(MersenneTwister(seed),1:n)]; nearest=copy(d[:,first(selected)])
    for _ in 2:count
        nearest[selected] .= -Inf
        j=argmax(nearest); push!(selected,j)
        nearest=min.(nearest,d[:,j])
    end
    selected
end

function pca_projection(matrix)
    centered = matrix .- mean(matrix; dims=2)
    f = svd(centered; full=false)
    coordinates = zeros(size(matrix,2),2)
    for k in 1:min(2,length(f.S))
        axis=f.U[:,k]
        signfix=axis[argmax(abs.(axis))]<0 ? -1.0 : 1.0
        coordinates[:,k] = vec(axis'*centered)*signfix
    end
    coordinates
end

function mds_projection(d; seed=2007)
    ids=landmarks(d, min(200,size(d,1)); seed)
    squared=d[ids,ids].^2
    colmean=mean(squared;dims=1); total=mean(squared)
    b=-0.5.*(squared.-mean(squared;dims=2).-colmean.+total)
    eig=eigen(Symmetric(b)); order=sortperm(eig.values;rev=true)
    cross=d[:,ids].^2
    bc=-0.5.*(cross.-mean(cross;dims=2).-colmean.+total)
    coords=zeros(size(d,1),2)
    for (k,j) in enumerate(order[1:min(2,length(order))])
        eig.values[j] > 1e-10 && (coords[:,k]=bc*eig.vectors[:,j]/sqrt(eig.values[j]))
    end
    coords
end

function diffusion_projection(d)
    size(d,1)<=600 || throw(ArgumentError("A lente de difusão desta versão aceita até 600 linhas; use PCA ou MDS para tabelas maiores."))
    positive=filter(>(0),vec(d)); σ=isempty(positive) ? 1.0 : median(positive)
    kernel=exp.(-(d./σ).^2); mass=vec(sum(kernel;dims=2))
    eig=eigen(Symmetric(kernel./sqrt.(mass*mass')))
    order=sortperm(eig.values;rev=true); coords=zeros(size(d,1),2)
    for k in 1:min(2,length(order)-1)
        j=order[k+1]; coords[:,k]=eig.values[j].*eig.vectors[:,j]./sqrt.(mass)
    end
    coords
end

function lens_values(name, matrix, d, ds, cache, cfg)
    if startswith(name,"column:")
        c=name[8:end]; c in ds.numeric || throw(ArgumentError("Lente: coluna numérica inexistente."))
        observed=Float64.(filter(!isnothing,ds.data[c])); m=median(observed)
        return Float64[isnothing(v) ? m : v for v in ds.data[c]]
    elseif name in ("pca1","pca2")
        coords=get!(cache,"pca") do; pca_projection(matrix); end
        return coords[:,name=="pca1" ? 1 : 2]
    elseif name in ("mds1","mds2")
        coords=get!(cache,"mds") do; mds_projection(d;seed=cfg["seed"]); end
        return coords[:,name=="mds1" ? 1 : 2]
    elseif name in ("diffusion1","diffusion2")
        coords=get!(cache,"diffusion") do; diffusion_projection(d); end
        return coords[:,name=="diffusion1" ? 1 : 2]
    elseif name=="eccentricity"
        return vec(mean(d;dims=2))
    elseif name=="eccentricity_inf"
        return vec(maximum(d;dims=2))
    elseif name=="density"
        k=min(12,size(d,1)-1)
        return [1/max(sort(d[i,:])[k+1],1e-10) for i in axes(d,1)]
    elseif name=="gaussian"
        positive=filter(>(0),vec(d)); σ=isempty(positive) ? 1.0 : median(positive)/3
        return vec(mean(exp.(-0.5.*(d./σ).^2);dims=2))
    elseif name=="norm"
        return vec(sqrt.(sum(abs2,matrix;dims=1)))
    elseif name=="index"
        return Float64.(1:rowcount(ds))
    end
    throw(ArgumentError("Lente desconhecida: $name."))
end

struct SeededKMeans{M} <: TDAmapper.Refiners.AbstractRefiner
    k::Int
    metric::M
    seed::Int
end
TDAmapper.validate(::SeededKMeans)=nothing
function (r::SeededKMeans)(points)
    length(points)==1 && return [1]
    Clustering.kmeans(MetricSpaces.as_matrix(points), min(r.k,length(points));
        distance=r.metric, rng=MersenneTwister(r.seed),maxiter=100).assignments
end

"""DBSCAN noise is represented as singleton nodes, never one artificial noise cluster."""
struct SingletonNoiseDBSCAN{M} <: TDAmapper.Refiners.AbstractRefiner
    radius::Float64
    neighbors::Int
    metric::M
end
TDAmapper.validate(::SingletonNoiseDBSCAN)=nothing
function (r::SingletonNoiseDBSCAN)(points)
    length(points)==1 && return [1]
    d=pairwise(r.metric,MetricSpaces.as_matrix(points);dims=2)
    labels=copy(Clustering.dbscan(d,r.radius;metric=nothing,min_neighbors=r.neighbors,min_cluster_size=1).assignments)
    next=maximum(labels)
    for i in eachindex(labels)
        labels[i]==0 && (next+=1;labels[i]=next)
    end
    labels
end

function refiner_for(cfg)
    metric=metric_for(cfg["metric"]); kind=cfg["cluster"]
    kind=="firstempty" && return TDAmapper.Refiners.FirstEmptyBin(num_bins=cfg["bins"],metric=metric)
    kind=="dbscan" && return SingletonNoiseDBSCAN(Float64(cfg["radius"]),cfg["min_neighbors"],metric)
    kind=="kmeans" && return SeededKMeans(cfg["k"],SqEuclidean(),cfg["seed"])
    kind=="trivial" && return TDAmapper.Refiners.Trivial()
    TDAmapper.Refiners.Hierarchical(linkage=Symbol(kind),threshold=cfg["radius"],metric=metric)
end

function construct_mapper(ds, cfg, matrix, d, lenses)
    points=MetricSpaces.EuclideanSpace(matrix)
    nerve=cfg["nerve"]=="jaccard" ? TDAmapper.Nerves.JaccardNerve(Float64(cfg["edge_threshold"])) : TDAmapper.Nerves.SimpleNerve()
    if cfg["algorithm"]=="ball"
        remaining=trues(rowcount(ds)); cells=Vector{Int}[]
        # Greedy epsilon net; stop with a clear error rather than leaving rows uncovered.
        while any(remaining)
            id=findfirst(remaining); cell=findall(<=(cfg["ball_radius"]),d[id,:])
            push!(cells,cell); remaining[cell].=false
            length(cells)<=cfg["max_landmarks"] || throw(ArgumentError("O raio gerou mais de $(cfg["max_landmarks"]) bolas. Aumente o raio ou o limite de centros."))
        end
        graph=TDAmapper.make_graph(points,cells,nerve)
        return TDAmapper.Mapper(X=points,C=cells,g=graph)
    end
    coordinates=cfg["cover"]=="quantile" ? map(equalized,lenses) : lenses
    covers=[TDAmapper.IntervalCovers.ManualCover(cover_intervals(f,cfg["resolution"],cfg["gain"])) for f in coordinates]
    cover=length(lenses)==1 ? TDAmapper.ImageCovers.R1Cover(coordinates[1],covers[1]) :
        TDAmapper.ImageCovers.R2Cover(collect(zip(coordinates...)),covers[1],covers[2])
    cells=TDAmapper.refine_cover(points,TDAmapper.make_cover(cover),refiner_for(cfg))
    length(cells)<=2000 || throw(ArgumentError("O modelo gerou mais de 2.000 nós. Reduza a resolução ou aumente o limiar de clustering."))
    graph=TDAmapper.make_graph(points,cells,nerve)
    TDAmapper.Mapper(X=points,C=cells,g=graph)
end

function build_context(ds, supplied)
    cfg=config_for(ds,supplied); matrix,audit=prepare(ds,cfg); d=distance_matrix(matrix,cfg["metric"])
    cache=Dict{String,Any}(); lensnames=String[cfg["lens1"]]
    cfg["lens2"]=="none" || push!(lensnames,cfg["lens2"])
    lenses=[lens_values(name,matrix,d,ds,cache,cfg) for name in lensnames]
    (;cfg,matrix,audit,d,lenses,cache)
end

function graph_payload(ds, M, context; elapsed=0.0)
    cfg=context.cfg; projection=pca_projection(context.matrix)
    components=connected_components(M.g); component_ids=zeros(Int,nv(M.g))
    for (i,c) in enumerate(components); component_ids[c].=i; end
    nodes=map(enumerate(M.C)) do (i,ids)
        summaries=Dict{String,Any}()
        for c in ds.columns
            values=filter(!isnothing,ds.data[c][ids])
            if isempty(values)
                summaries[c]=Dict("mean"=>nothing,"median"=>nothing,"min"=>nothing,"max"=>nothing,"std"=>nothing)
            elseif c in ds.numeric
                summaries[c]=Dict("mean"=>mean(values),"median"=>median(values),"min"=>minimum(values),"max"=>maximum(values),"std"=>length(values)>1 ? std(values) : 0.0)
            else
                counts=Dict(v=>count(==(v),values) for v in unique(values))
                label=first(sort(collect(keys(counts));by=x->(-counts[x],x)))
                summaries[c]=Dict("mode"=>label,"counts"=>counts,"purity"=>counts[label]/length(values))
            end
        end
        Dict("id"=>i,"members"=>ids,"size"=>length(ids),"degree"=>degree(M.g,i),"component"=>component_ids[i],
            "x"=>mean(projection[ids,1]),"y"=>mean(projection[ids,2]),
            "lens"=>[mean(f[ids]) for f in context.lenses],"values"=>summaries)
    end
    links=[Dict("source"=>src(e),"target"=>dst(e),"shared"=>length(intersect(M.C[src(e)],M.C[dst(e)]))) for e in edges(M.g)]
    covered=sort!(unique(vcat(Int[],M.C...)))
    Dict{String,Any}("id"=>string(uuid4()),"dataset_id"=>ds.id,"config"=>cfg,"nodes"=>nodes,"edges"=>links,
        "projection"=>[Dict("id"=>i,"x"=>projection[i,1],"y"=>projection[i,2]) for i in 1:rowcount(ds)],
        "lenses"=>context.lenses,"preprocessing"=>context.audit,
        "summary"=>Dict("nodes"=>nv(M.g),"edges"=>ne(M.g),"components"=>length(components),
            "graph_cycles"=>ne(M.g)-nv(M.g)+length(components),"coverage"=>length(covered)/rowcount(ds),
            "rows"=>rowcount(ds),"elapsed"=>elapsed,"overlap"=>1-1/cfg["gain"]),
        "notes"=>["Os ciclos do grafo são E−V+C; não são a homologia da nuvem nem do nervo simplicial.",
            "Uma linha pode pertencer a vários nós; grupos e Explain deduplicam as linhas.",
            "Equalização usa postos médios em empates; o ganho descreve a sobreposição no espaço de postos."])
end

function analyze(ds::Dataset, supplied=Dict())
    started=time(); context=build_context(ds,supplied)
    M=construct_mapper(ds,context.cfg,context.matrix,context.d,context.lenses)
    graph_payload(ds,M,context;elapsed=time()-started)
end

function sensitivity(ds, supplied; resolutions=[6,10,14,18], gains=[1.3,1.7,2.2])
    1<=length(resolutions)*length(gains)<=20 || throw(ArgumentError("Compare até 20 configurações."))
    context=build_context(ds,supplied); results=Any[]
    context.cfg["algorithm"]=="classic" || throw(ArgumentError("A comparação de resolução e ganho requer Mapper clássico. Ball Mapper usa raio e centros."))
    for resolution in resolutions, gain in gains
        cfg=config_for(ds,merge(context.cfg,Dict("resolution"=>resolution,"gain"=>gain)))
        t=time(); M=construct_mapper(ds,cfg,context.matrix,context.d,context.lenses)
        c=length(connected_components(M.g)); covered=length(unique(vcat(Int[],M.C...)))
        push!(results,Dict("resolution"=>resolution,"gain"=>gain,"nodes"=>nv(M.g),"edges"=>ne(M.g),
            "components"=>c,"graph_cycles"=>ne(M.g)-nv(M.g)+c,"coverage"=>covered/rowcount(ds),"elapsed"=>time()-t))
    end
    Dict("results"=>results,"note"=>"Análise descritiva de sensibilidade. Nenhuma configuração é declarada ótima ou estatisticamente estável.")
end
