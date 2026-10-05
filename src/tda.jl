function diagram_payload(diagrams, threshold)
    bars=Any[]; summaries=Any[]
    for (dimension,diagram) in enumerate(diagrams)
        lengths=Float64[]
        for interval in diagram
            b,d=TDARipserer.birth(interval),TDARipserer.death(interval)
            push!(bars,Dict("dimension"=>dimension-1,"birth"=>b,"death"=>isfinite(d) ? d : nothing,
                "persistence"=>isfinite(d) ? d-b : nothing))
            isfinite(d) && d>b && push!(lengths,d-b)
        end
        total=sum(lengths)
        entropy=total>0 ? -sum(p*log(p) for p in lengths./total) : 0.0
        push!(summaries,Dict("dimension"=>dimension-1,"features"=>length(diagram),
            "finite"=>length(lengths),"max_persistence"=>isempty(lengths) ? 0.0 : maximum(lengths),"entropy"=>entropy))
    end
    ts=collect(range(0,max(threshold,1e-10);length=80))
    curves=[Dict("dimension"=>dim,"values"=>[count(b -> b["dimension"]==dim && b["birth"]<=t && (isnothing(b["death"]) || t<b["death"]),bars) for t in ts]) for dim in 0:length(diagrams)-1]
    Dict("bars"=>bars,"summary"=>summaries,"scales"=>ts,"betti"=>curves,"threshold"=>threshold,"coefficients"=>"F₂")
end

function image_analysis(rows; filtration="grayscale", cutoff=0.5, invert=false)
    rows isa AbstractVector && 3<=length(rows)<=96 || throw(ArgumentError("The image must have 3 to 96 rows of pixels."))
    all(r -> r isa AbstractVector,rows) || throw(ArgumentError("Pixels must be a matrix of rows."))
    width=length(first(rows)); 3<=width<=96 && all(r->length(r)==width,rows) || throw(ArgumentError("The image must have 3 to 96 columns of equal width."))
    all(v -> v isa Real && isfinite(v) && 0<=v<=1,Iterators.flatten(rows)) || throw(ArgumentError("Pixel values must be numbers between 0 and 1."))
    cutoff isa Real && isfinite(cutoff) && 0<=cutoff<=1 || throw(ArgumentError("The binary threshold must be between 0 and 1."))
    invert isa Bool || throw(ArgumentError("Invert must be a Boolean."))
    A=[Float64(rows[i][j]) for i in eachindex(rows),j in 1:width]
    invert && (A=1 .- A)
    if filtration!="grayscale"
        filtration in ("height","radial","dilation","erosion","signed_distance") || throw(ArgumentError("Unknown image filtration."))
        mask=A.<=cutoff; any(mask) || throw(ArgumentError("No pixels belong to the object. Adjust the threshold or invert the image."))
        A=MetricSpaces.ImageFiltration(Symbol(filtration))(mask)
    end
    finite=filter(isfinite,vec(A)); offset=minimum(finite); transformed=A.-offset
    threshold=max(maximum(finite)-offset,1e-10)
    diagrams=TDARipserer.image_persistence(transformed;dim_max=1,threshold=threshold)
    result=diagram_payload(diagrams,threshold)
    scales=collect(range(0,threshold;length=80))
    curve=MetricSpaces.cubical_ecc(transformed;thresholds=scales,mask=isfinite.(transformed))
    result["euler"]=Dict("scales"=>scales,"values"=>curve.values)
    result["image_shape"]=collect(size(A));result["filtration"]=filtration;result["offset"]=offset
    result["note"]="Cubical lower-star on image vertices, with unit pixel spacing. Filtration values shifted by $offset to start at zero. Masks use pixels ≤ threshold; Inf background is excluded. Bars without a death are essential or censored."
    result
end

function persistence_analysis(ds, supplied=Dict(); selected=nothing, sample=220, dimension=1, threshold=nothing)
    dimension in 0:2 || throw(ArgumentError("Dimension must be 0, 1 or 2."))
    limit=dimension==2 ? 80 : 300
    sample isa Integer && 3<=sample<=limit || throw(ArgumentError("Use between 3 and $limit landmarks for this dimension."))
    context=build_context(ds,supplied)
    ids=isnothing(selected) || isempty(selected) ? collect(1:rowcount(ds)) : checked_ids(ds,selected)
    length(ids)>=3 || throw(ArgumentError("Persistence requires at least three rows."))
    d=context.d[ids,ids]; chosen=landmarks(d,min(sample,length(ids));seed=context.cfg["seed"])
    requested=length(chosen)
    representatives=Int[]
    for i in chosen
        any(j -> d[i,j]<=1e-12 && maximum(abs.(d[i,:].-d[j,:]))<=1e-10,representatives) || push!(representatives,i)
    end
    chosen=representatives
    sampled=d[chosen,chosen]; maxscale=maximum(sampled)
    t=isnothing(threshold) ? max(maxscale,1e-10) : threshold
    t isa Real && isfinite(t) && 0<t<=max(maxscale,1e-10) || throw(ArgumentError("The maximum scale must be positive and no greater than the landmark diameter."))
    t=max(t,1e-10)
    computed_dimension=min(dimension,max(0,length(chosen)-2))
    diagrams=length(chosen)==1 ? [TDAPersistenceDiagrams.PersistenceDiagram([(0.0,Inf)];dim=0)] :
        TDARipserer.ripserer(sampled;dim_max=computed_dimension,threshold=t)
    for dim in length(diagrams):dimension
        push!(diagrams,TDAPersistenceDiagrams.PersistenceDiagram(Tuple{Float64,Float64}[];dim=dim))
    end
    result=diagram_payload(diagrams,t)
    result["landmarks"]=ids[chosen]; result["source_n"]=length(ids); result["sample_n"]=length(chosen)
    result["metric"]=context.cfg["metric"];result["zero_distance_collapsed"]=requested-length(chosen)
    result["note"]="Vietoris–Rips of landmarks in the preprocessed space, using the selected metric. Bars without a death are essential or censored at the maximum scale. Sampling may alter topology."
    result
end

function clustering_analysis(ds, supplied=Dict(); k=12, tau=0.2)
    k isa Integer && 2<=k<=50 || throw(ArgumentError("k must be between 2 and 50."))
    tau isa Real && isfinite(tau) && 0<=tau<=1e6 || throw(ArgumentError("τ must be finite and nonnegative."))
    context=build_context(ds,supplied); d=context.d; n=rowcount(ds); k=min(k,n-1)
    graph=SimpleGraph(n); density=Float64[]
    for i in 1:n
        neighbors=sortperm(d[i,:]); filter!(!=(i),neighbors); ids=neighbors[1:k]
        for j in ids; add_edge!(graph,i,j); end
        push!(density,1/max(d[i,last(ids)],1e-10))
    end
    # Stable tie-breaking, smaller than a unit in the display precision.
    for i in eachindex(density); density[i]+=eps(density[i])*i; end
    labels,peaks=ToMATo.tomato(MetricSpaces.EuclideanSpace(context.matrix),graph,density,tau)
    groups=[Dict("name"=>"ToMATo $label","rows"=>findall(==(label),labels)) for label in sort!(unique(labels))]
    Dict("labels"=>labels,"groups"=>groups,"density"=>density,
        "peaks"=>[Dict("row"=>i,"birth"=>v[1],"death"=>isfinite(v[2]) ? v[2] : nothing) for (i,v) in sort!(collect(peaks);by=first)],
        "note"=>"ToMATo on a symmetrized k-NN graph; density is 1/distance to the k-th neighbor. τ uses density units, and groups deduplicate rows.")
end

function timeseries_analysis(ds, column; dimension=3, delay=2, window=60, step=30, maxdim=1)
    column in ds.numeric || throw(ArgumentError("Choose a numeric series."))
    dimension isa Integer && 2<=dimension<=8 || throw(ArgumentError("Embedding dimension must be between 2 and 8."))
    delay isa Integer && 1<=delay<=100 || throw(ArgumentError("Delay must be between 1 and 100."))
    window isa Integer && 5<=window<=100 || throw(ArgumentError("Window size must be between 5 and 100 states."))
    step isa Integer && 1<=step<=300 || throw(ArgumentError("Step must be between 1 and 300."))
    maxdim in 0:1 || throw(ArgumentError("Time series support H0/H1 in this interface."))
    raw=ds.data[column]; any(isnothing,raw) && throw(ArgumentError("The series cannot contain missing values; regularize and complete it before importing."))
    series=Float64.(raw); count=length(series)-(dimension-1)*delay
    count>=window || throw(ArgumentError("The series is too short for the selected embedding and window."))
    floor(Int,(count-window)/step)+1<=25 || throw(ArgumentError("Increase the step: at most 25 windows are allowed."))
    points=[[series[i+j*delay] for j in 0:dimension-1] for i in 1:count]
    windows=TDARipserer.sliding_window_ph(points;window,step,dim_max=maxdim)
    results=map(windows) do w
        maximum_persistence=[maximum((TDARipserer.death(v)-TDARipserer.birth(v) for v in diagram if isfinite(TDARipserer.death(v)));init=0.0) for diagram in w.diagrams]
        Dict("start"=>w.start,"stop"=>w.stop,"source_stop"=>w.stop+(dimension-1)*delay,"max_persistence"=>maximum_persistence)
    end
    Dict("windows"=>results,"embedding_n"=>count,"note"=>"CSV row order defines time. Delay and step are indices; use regularly spaced samples. Overlapping windows are dependent. Euclidean distances on the original series, without normalization.")
end

function multiparameter_analysis(ds, supplied=Dict(); sample=24, dimension=0)
    sample isa Integer && 5<=sample<=28 || throw(ArgumentError("Use between 5 and 28 landmarks."))
    dimension in 0:1 || throw(ArgumentError("The surface supports H0/H1."))
    context=build_context(ds,supplied)
    context.cfg["metric"]=="euclidean" || throw(ArgumentError("Function-Rips requires the Euclidean metric in this interface."))
    ids=landmarks(context.d,min(sample,rowcount(ds));seed=context.cfg["seed"])
    points=collect(eachcol(context.matrix[:,ids])); values=context.lenses[1][ids]
    scale=max(maximum(context.d[ids,ids]),1e-8); lo,hi=extrema(values); hi==lo && (hi=lo+1e-8)
    scales=collect(range(0,scale;length=10)); levels=collect(range(lo,hi;length=10))
    f=MultiparameterPersistence.bifiltration(points,values;dim_max=dimension,max_scale=scale,max_simplices=5000)
    hilbert=MultiparameterPersistence.hilbert_function(f;scales,levels,dim=dimension)
    euler=MultiparameterPersistence.euler_surface(f;scales,levels)
    Dict("scales"=>scales,"levels"=>levels,"hilbert"=>[collect(hilbert.values[i,:]) for i in axes(hilbert.values,1)],
        "euler"=>[collect(euler.values[i,:]) for i in axes(euler.values,1)],"dimension"=>dimension,"landmarks"=>ids,
        "simplices"=>length(f.simplices),"note"=>"Exact function-Rips over F₂ on landmarks: scale × first lens. The Euler surface describes the truncated complex, not omitted dimensions. At most 28 landmarks and a 10×10 grid.")
end
