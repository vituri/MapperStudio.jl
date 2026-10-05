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
    rows isa AbstractVector && 3<=length(rows)<=96 || throw(ArgumentError("A imagem precisa de 3 a 96 linhas de pixels."))
    all(r -> r isa AbstractVector,rows) || throw(ArgumentError("Pixels devem ser uma matriz de linhas."))
    width=length(first(rows)); 3<=width<=96 && all(r->length(r)==width,rows) || throw(ArgumentError("A imagem precisa de 3 a 96 colunas, com largura constante."))
    all(v -> v isa Real && isfinite(v) && 0<=v<=1,Iterators.flatten(rows)) || throw(ArgumentError("Pixels devem ser números entre 0 e 1."))
    cutoff isa Real && isfinite(cutoff) && 0<=cutoff<=1 || throw(ArgumentError("Limiar binário entre 0 e 1."))
    invert isa Bool || throw(ArgumentError("Inversão deve ser booleana."))
    A=[Float64(rows[i][j]) for i in eachindex(rows),j in 1:width]
    invert && (A=1 .- A)
    if filtration!="grayscale"
        filtration in ("height","radial","dilation","erosion","signed_distance") || throw(ArgumentError("Filtragem de imagem desconhecida."))
        mask=A.<=cutoff; any(mask) || throw(ArgumentError("Nenhum pixel pertence ao objeto. Ajuste o limiar ou inverta a imagem."))
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
    result["note"]="Cubical lower-star nos vértices da imagem, com pixels unitários. Valores de filtragem deslocados por $offset para começar em zero. Máscaras usam pixels ≤ limiar; fundo Inf é excluído. Barras sem morte são essenciais ou censuradas."
    result
end

function persistence_analysis(ds, supplied=Dict(); selected=nothing, sample=220, dimension=1, threshold=nothing)
    dimension in 0:2 || throw(ArgumentError("Dimensão deve ser 0, 1 ou 2."))
    limit=dimension==2 ? 80 : 300
    sample isa Integer && 3<=sample<=limit || throw(ArgumentError("Use entre 3 e $limit marcos para esta dimensão."))
    context=build_context(ds,supplied)
    ids=isnothing(selected) || isempty(selected) ? collect(1:rowcount(ds)) : checked_ids(ds,selected)
    length(ids)>=3 || throw(ArgumentError("A persistência requer ao menos três linhas."))
    d=context.d[ids,ids]; chosen=landmarks(d,min(sample,length(ids));seed=context.cfg["seed"])
    requested=length(chosen)
    representatives=Int[]
    for i in chosen
        any(j -> d[i,j]<=1e-12 && maximum(abs.(d[i,:].-d[j,:]))<=1e-10,representatives) || push!(representatives,i)
    end
    chosen=representatives
    sampled=d[chosen,chosen]; maxscale=maximum(sampled)
    t=isnothing(threshold) ? max(maxscale,1e-10) : threshold
    t isa Real && isfinite(t) && 0<t<=max(maxscale,1e-10) || throw(ArgumentError("A escala máxima deve ser positiva e não maior que o diâmetro dos marcos."))
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
    result["note"]="Vietoris–Rips dos marcos no espaço pré-processado, com a métrica escolhida. Barras sem morte são essenciais ou censuradas na escala máxima. A amostragem pode alterar a topologia."
    result
end

function clustering_analysis(ds, supplied=Dict(); k=12, tau=0.2)
    k isa Integer && 2<=k<=50 || throw(ArgumentError("k deve estar entre 2 e 50."))
    tau isa Real && isfinite(tau) && 0<=tau<=1e6 || throw(ArgumentError("τ deve ser finito e não negativo."))
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
        "note"=>"ToMATo em grafo k-NN simetrizado; densidade 1/distância ao k-ésimo vizinho. τ usa unidades de densidade, e os grupos deduplicam as linhas.")
end

function timeseries_analysis(ds, column; dimension=3, delay=2, window=60, step=30, maxdim=1)
    column in ds.numeric || throw(ArgumentError("Escolha uma série numérica."))
    dimension isa Integer && 2<=dimension<=8 || throw(ArgumentError("Dimensão de embedding entre 2 e 8."))
    delay isa Integer && 1<=delay<=100 || throw(ArgumentError("Atraso entre 1 e 100."))
    window isa Integer && 5<=window<=100 || throw(ArgumentError("Janela entre 5 e 100 estados."))
    step isa Integer && 1<=step<=300 || throw(ArgumentError("Passo entre 1 e 300."))
    maxdim in 0:1 || throw(ArgumentError("Séries suportam H0/H1 nesta interface."))
    raw=ds.data[column]; any(isnothing,raw) && throw(ArgumentError("A série não pode ter valores ausentes; regularize e complete antes de importar."))
    series=Float64.(raw); count=length(series)-(dimension-1)*delay
    count>=window || throw(ArgumentError("A série é curta para embedding e janela escolhidos."))
    floor(Int,(count-window)/step)+1<=25 || throw(ArgumentError("Aumente o passo: limite de 25 janelas."))
    points=[[series[i+j*delay] for j in 0:dimension-1] for i in 1:count]
    windows=TDARipserer.sliding_window_ph(points;window,step,dim_max=maxdim)
    results=map(windows) do w
        maximum_persistence=[maximum((TDARipserer.death(v)-TDARipserer.birth(v) for v in diagram if isfinite(TDARipserer.death(v)));init=0.0) for diagram in w.diagrams]
        Dict("start"=>w.start,"stop"=>w.stop,"source_stop"=>w.stop+(dimension-1)*delay,"max_persistence"=>maximum_persistence)
    end
    Dict("windows"=>results,"embedding_n"=>count,"note"=>"A ordem do CSV define o tempo. Atraso e passo são índices; use amostras regulares. Janelas sobrepostas são dependentes. Distâncias euclidianas na série original, sem normalização.")
end

function multiparameter_analysis(ds, supplied=Dict(); sample=24, dimension=0)
    sample isa Integer && 5<=sample<=28 || throw(ArgumentError("Use entre 5 e 28 marcos."))
    dimension in 0:1 || throw(ArgumentError("A superfície suporta H0/H1."))
    context=build_context(ds,supplied)
    context.cfg["metric"]=="euclidean" || throw(ArgumentError("Function-Rips nesta interface requer a métrica euclidiana."))
    ids=landmarks(context.d,min(sample,rowcount(ds));seed=context.cfg["seed"])
    points=collect(eachcol(context.matrix[:,ids])); values=context.lenses[1][ids]
    scale=max(maximum(context.d[ids,ids]),1e-8); lo,hi=extrema(values); hi==lo && (hi=lo+1e-8)
    scales=collect(range(0,scale;length=10)); levels=collect(range(lo,hi;length=10))
    f=MultiparameterPersistence.bifiltration(points,values;dim_max=dimension,max_scale=scale,max_simplices=5000)
    hilbert=MultiparameterPersistence.hilbert_function(f;scales,levels,dim=dimension)
    euler=MultiparameterPersistence.euler_surface(f;scales,levels)
    Dict("scales"=>scales,"levels"=>levels,"hilbert"=>[collect(hilbert.values[i,:]) for i in axes(hilbert.values,1)],
        "euler"=>[collect(euler.values[i,:]) for i in axes(euler.values,1)],"dimension"=>dimension,"landmarks"=>ids,
        "simplices"=>length(f.simplices),"note"=>"Function-Rips exato sobre F₂ nos marcos: escala × primeira lente. A superfície de Euler é do complexo truncado, não de dimensões omitidas. Limite de 28 marcos e grade 10×10.")
end
