"""A table retaining original row identities, numeric values and categorical labels."""
struct Dataset
    id::String
    name::String
    columns::Vector{String}
    data::Dict{String,Vector{Any}}
    numeric::Vector{String}
end

function Dataset(name, columns, data)
    cols = String.(columns)
    length(cols) <= 160 || throw(ArgumentError("Máximo de 160 colunas por tabela."))
    allunique(cols) || throw(ArgumentError("Os nomes das colunas devem ser únicos."))
    !isempty(cols) || throw(ArgumentError("A tabela precisa de colunas."))
    n = length(data[first(cols)])
    3 <= n <= MAX_ROWS || throw(ArgumentError("Use entre 3 e $MAX_ROWS linhas. Nenhuma linha foi amostrada silenciosamente."))
    all(c -> length(data[c]) == n, cols) || throw(ArgumentError("Colunas com números de linhas diferentes."))
    cleaned = Dict{String,Vector{Any}}()
    numeric = String[]
    for c in cols
        values = Any[ismissing(v) || isnothing(v) || (v isa AbstractString && isempty(strip(v))) ? nothing : v for v in data[c]]
        observed = filter(!isnothing, values)
        isnum = !isempty(observed) && all(v -> v isa Real || (v isa AbstractString && !isnothing(tryparse(Float64, v))), observed)
        if isnum
            values = Any[isnothing(v) ? nothing : v isa Real ? Float64(v) : parse(Float64, v) for v in values]
            all(v -> isnothing(v) || isfinite(v), values) || throw(ArgumentError("A coluna $c contém NaN ou infinito."))
            push!(numeric, c)
        else
            values = Any[isnothing(v) ? nothing : String(string(v)) for v in values]
        end
        cleaned[c] = values
    end
    !isempty(numeric) || throw(ArgumentError("A tabela precisa de pelo menos uma coluna numérica."))
    Dataset(string(uuid4()), String(name), cols, cleaned, numeric)
end

function parse_csv(content::AbstractString; name="Dados importados")
    sizeof(content) <= MAX_BYTES || throw(ArgumentError("O CSV deve ter até 20 MB."))
    file = CSV.File(IOBuffer(content); normalizenames=false, limit=MAX_ROWS+1,
                    silencewarnings=true, strict=true)
    cols = String.(propertynames(file))
    Dataset(name, cols, Dict(c => Any[collect(getproperty(file, Symbol(c)))...] for c in cols))
end

rowcount(ds::Dataset) = length(ds.data[first(ds.columns)])

function dataset_summary(ds::Dataset; include_rows=false)
    cols = map(ds.columns) do c
        observed = filter(!isnothing, ds.data[c])
        numeric = c in ds.numeric
        Dict("name"=>c, "type"=>numeric ? "numeric" : "categorical",
            "missing"=>rowcount(ds)-length(observed), "unique"=>length(unique(observed)),
            "min"=>numeric ? minimum(observed) : nothing,
            "max"=>numeric ? maximum(observed) : nothing,
            "mean"=>numeric ? mean(observed) : nothing)
    end
    result = Dict{String,Any}("id"=>ds.id, "name"=>ds.name, "n"=>rowcount(ds), "columns"=>cols, "numeric"=>ds.numeric)
    include_rows && (result["rows"] = [Dict(c=>ds.data[c][i] for c in ds.columns) for i in 1:rowcount(ds)])
    result
end

function demo_dataset(kind="branches"; n=600, seed=2007)
    rng = MersenneTwister(seed)
    kind == "diabetes" && return parse_csv(read(joinpath(APP_ROOT, "data", "diabetes.csv"), String); name="Diabetes · Reaven & Miller")
    kind in ("branches", "circle", "torus", "clusters") || throw(ArgumentError("Exemplo desconhecido."))
    3 <= n <= MAX_ROWS || throw(ArgumentError("Número de pontos fora do limite."))
    x, y, z, signal = (Float64[] for _ in 1:4)
    labels = String[]
    for _ in 1:n
        t = rand(rng)
        if kind == "branches"
            branch = rand(rng, 1:3)
            θ = (branch-1)*2π/3 + 0.09randn(rng)
            radius = 0.12 + 2.8t
            a, b, c = radius*cos(θ), radius*sin(θ), 0.08randn(rng)
            label = ["Exploração", "Transição", "Expansão"][branch]
            s = 30 + 45t + 12(branch-1) + 4randn(rng)
        elseif kind == "circle"
            θ = 2π*t; radius = 1 + 0.035randn(rng)
            a, b, c = radius*cos(θ), radius*sin(θ), 0.025randn(rng)
            label = θ < π ? "Arco superior" : "Arco inferior"; s = 50+40sin(θ)+randn(rng)
        elseif kind == "torus"
            θ, φ = 2π*t, 2π*rand(rng)
            a, b, c = (2+0.65cos(φ))*cos(θ), (2+0.65cos(φ))*sin(θ), 0.65sin(φ)
            label = φ < π ? "Face superior" : "Face inferior"; s = 50+35sin(φ)
        else
            branch = rand(rng, 1:3)
            a, b, c = 2.5cos(2π*branch/3)+0.3randn(rng), 2.5sin(2π*branch/3)+0.3randn(rng), 0.2randn(rng)
            label = "Grupo $branch"; s = 20branch+5randn(rng)
        end
        push!(x,a); push!(y,b); push!(z,c); push!(signal,s); push!(labels,label)
    end
    names = Dict("branches"=>"Três caminhos", "circle"=>"Círculo com ruído", "torus"=>"Toro", "clusters"=>"Três populações")
    cols = ["x", "y", "z", "intensidade", "população"]
    Dataset(names[kind], cols, Dict{String,Vector{Any}}("x"=>x,"y"=>y,"z"=>z,"intensidade"=>signal,"população"=>labels))
end

const DEFAULT_CONFIG = Dict{String,Any}(
    "columns"=>String[], "scaling"=>"standard", "missing"=>"median",
    "metric"=>"euclidean", "algorithm"=>"classic", "lens1"=>"pca1", "lens2"=>"pca2",
    "resolution"=>12, "gain"=>1.7, "cover"=>"uniform", "cluster"=>"firstempty",
    "bins"=>10, "radius"=>0.35, "min_neighbors"=>3, "k"=>2,
    "nerve"=>"intersection", "edge_threshold"=>0.1, "seed"=>2007,
    "ball_radius"=>0.5, "max_landmarks"=>180)

function config_for(ds, supplied)
    supplied isa AbstractDict || throw(ArgumentError("A configuração deve ser um objeto de opções."))
    params=Dict{String,Any}(String(k)=>v for (k,v) in pairs(supplied))
    cfg = merge(copy(DEFAULT_CONFIG),params)
    cfg["columns"] isa AbstractVector || throw(ArgumentError("Selecione uma lista de variáveis numéricas."))
    haskey(params,"columns") && isempty(cfg["columns"]) && throw(ArgumentError("Selecione entre 1 e $MAX_COLUMNS variáveis numéricas."))
    isempty(cfg["columns"]) && (cfg["columns"] = filter(c -> !occursin(r"(?i)(^id$|_id$)",c), ds.numeric))
    isempty(cfg["columns"]) && (cfg["columns"] = copy(ds.numeric))
    cfg["columns"] = String.(cfg["columns"])
    allunique(cfg["columns"]) || throw(ArgumentError("Selecione cada variável uma vez."))
    1 <= length(cfg["columns"]) <= MAX_COLUMNS || throw(ArgumentError("Selecione entre 1 e $MAX_COLUMNS variáveis numéricas."))
    all(c -> c in ds.numeric, cfg["columns"]) || throw(ArgumentError("A geometria aceita apenas colunas numéricas existentes."))
    for (key,lo,hi) in (("resolution",2,40),("bins",2,50),("min_neighbors",1,100),("k",1,12),("max_landmarks",3,300),("seed",0,typemax(Int32)))
        cfg[key] isa Integer && lo <= cfg[key] <= hi || throw(ArgumentError("$key deve ser inteiro entre $lo e $hi."))
    end
    for (key,lo,hi) in (("gain",1.0,5.0),("radius",1e-6,1e6),("ball_radius",1e-6,1e6),("edge_threshold",1e-6,0.999))
        cfg[key] isa Real && isfinite(cfg[key]) && lo <= cfg[key] <= hi || throw(ArgumentError("$key deve estar entre $lo e $hi."))
    end
    for (key, choices) in (("scaling",("standard","robust","minmax","none")),("missing",("median","reject")),
        ("metric",("euclidean","manhattan","chebyshev","cosine","correlation")),("algorithm",("classic","ball")),
        ("cover",("uniform","quantile")),("cluster",("firstempty","dbscan","single","complete","average","kmeans","trivial")),
        ("nerve",("intersection","jaccard")))
        cfg[key] in choices || throw(ArgumentError("Opção inválida para $key."))
    end
    cfg["cluster"] == "kmeans" && cfg["metric"] != "euclidean" && throw(ArgumentError("K-means requer a métrica euclidiana. Use ligação hierárquica para outras métricas."))
    cfg
end

function prepare(ds, cfg)
    n = rowcount(ds); matrix = Matrix{Float64}(undef, length(cfg["columns"]), n)
    audit = Any[]
    for (j,c) in enumerate(cfg["columns"])
        raw = ds.data[c]; observed = Float64.(filter(!isnothing,raw))
        any(isnothing,raw) && cfg["missing"] == "reject" && throw(ArgumentError("$c tem valores ausentes. Escolha imputação pela mediana."))
        m = median(observed)
        values = Float64[isnothing(v) ? m : v for v in raw]
        mode = cfg["scaling"]
        offset = mode == "standard" ? mean(values) : mode == "robust" ? median(values) : mode == "minmax" ? minimum(values) : 0.0
        scale = mode == "standard" ? std(values) : mode == "robust" ? quantile(values,0.75)-quantile(values,0.25) : mode == "minmax" ? maximum(values)-minimum(values) : 1.0
        scale = scale > eps(Float64) ? scale : 1.0
        matrix[j,:] = (values .- offset) ./ scale
        push!(audit,Dict("column"=>c,"imputed"=>count(isnothing,raw),"median"=>m,"offset"=>offset,"scale"=>scale))
    end
    matrix,audit
end

metric_for(name) = Dict("euclidean"=>Euclidean(),"manhattan"=>Cityblock(),"chebyshev"=>Chebyshev(),"cosine"=>CosineDist(),"correlation"=>CorrDist())[name]

function distance_matrix(matrix, name)
    if name == "cosine"
        all(col -> norm(col)>eps(Float64), eachcol(matrix)) || throw(ArgumentError("Cosseno requer linhas não nulas após o pré-processamento."))
    elseif name == "correlation"
        size(matrix,1)>=2 && all(col -> std(col)>eps(Float64),eachcol(matrix)) || throw(ArgumentError("Correlação requer pelo menos duas variáveis e variação em cada linha."))
    end
    d = pairwise(metric_for(name), matrix; dims=2)
    d = max.(0.0, (d+d')/2)
    d[diagind(d)] .= 0
    all(isfinite,d) || throw(ArgumentError("A métrica produziu distâncias não finitas."))
    d
end
