const DATASETS = Dict{String,Dataset}()
const ANALYSES = Dict{String,Dict{String,Any}}()
const DATA_ORDER = String[]
const ANALYSIS_ORDER = String[]
const STORE_LOCK = ReentrantLock()
const COMPUTE_LIMIT = Base.Semaphore(1)

function save_dataset(ds)
    lock(STORE_LOCK) do
        DATASETS[ds.id]=ds; push!(DATA_ORDER,ds.id)
        while length(DATA_ORDER)>8
            delete!(DATASETS,popfirst!(DATA_ORDER))
        end
    end
    ds
end

function get_dataset(id)
    lock(STORE_LOCK) do
        haskey(DATASETS,id) || throw(KeyError("Tabela não encontrada. Reimporte o CSV ou abra o workspace."))
        DATASETS[id]
    end
end

function save_analysis(result)
    lock(STORE_LOCK) do
        ANALYSES[result["id"]]=result; push!(ANALYSIS_ORDER,result["id"])
        while length(ANALYSIS_ORDER)>16; delete!(ANALYSES,popfirst!(ANALYSIS_ORDER)); end
    end
    result
end

function json_response(value;status=200)
    HTTP.Response(status,["Content-Type"=>"application/json; charset=utf-8","Cache-Control"=>"no-store","X-Content-Type-Options"=>"nosniff"],JSON3.write(value))
end

function parsed_body(req)
    length(req.body)<=MAX_BYTES || throw(ArgumentError("Requisição maior que 20 MB."))
    isempty(req.body) && return Dict{String,Any}()
    try
        value=JSON3.read(String(req.body),Dict{String,Any})
        value isa AbstractDict || throw(ArgumentError("Envie um objeto JSON."))
        value
    catch err
        err isa ArgumentError && rethrow()
        throw(ArgumentError("JSON inválido."))
    end
end

function computed(f)
    Base.acquire(COMPUTE_LIMIT)
    try
        kind,value=fetch(Threads.@spawn try; (:ok,f()); catch err; (:error,err); end)
        kind==:error && throw(value)
        value
    finally
        Base.release(COMPUTE_LIMIT)
    end
end

function export_rows(ds, ids)
    selected=checked_ids(ds,ids;allow_empty=true)
    rows=[(; (Symbol(c)=>ds.data[c][i] for c in ds.columns)...) for i in selected]
    io=IOBuffer()
    if isempty(rows)
        CSV.write(io,[(; (Symbol(c)=>nothing for c in ds.columns)...)];writeheader=true)
        return first(split(String(take!(io)),'\n'))*"\n"
    end
    CSV.write(io,rows)
    String(take!(io))
end

function route(req)
    path=first(split(String(req.target),'?')); method=String(req.method)
    if method=="GET" && path=="/api/health"
        return json_response(Dict("status"=>"ok","version"=>"0.1.0","julia"=>string(VERSION),"max_rows"=>MAX_ROWS))
    elseif method=="GET" && path=="/api/catalog"
        return json_response(Dict("defaults"=>DEFAULT_CONFIG,"demos"=>["branches","circle","torus","clusters","diabetes"],"max_rows"=>MAX_ROWS))
    elseif method=="GET" && startswith(path,"/api/datasets/")
        ds=get_dataset(last(split(path,'/')))
        return json_response(dataset_summary(ds;include_rows=true))
    elseif method=="POST" && startswith(path,"/api/")
        body=parsed_body(req)
        if path=="/api/demo"
            ds=save_dataset(demo_dataset(get(body,"kind","branches");n=get(body,"n",600),seed=get(body,"seed",2007)))
            return json_response(dataset_summary(ds;include_rows=true))
        elseif path=="/api/import"
            ds=save_dataset(parse_csv(body["csv"];name=get(body,"name","Dados importados")))
            return json_response(dataset_summary(ds;include_rows=true))
        elseif path=="/api/image"
            return json_response(computed(() -> image_analysis(body["pixels"];filtration=get(body,"filtration","grayscale"),cutoff=get(body,"cutoff",0.5),invert=get(body,"invert",false))))
        end
        ds=get_dataset(body["dataset_id"]); cfg=get(body,"config",Dict{String,Any}())
        if path=="/api/mapper"
            return json_response(computed(() -> save_analysis(analyze(ds,cfg))))
        elseif path=="/api/explain"
            return json_response(computed(() -> explain(ds,body["selected"];reference=get(body,"reference",nothing),permutations=get(body,"permutations",199),seed=get(body,"seed",2007))))
        elseif path=="/api/persistence"
            return json_response(computed(() -> persistence_analysis(ds,cfg;selected=get(body,"selected",nothing),sample=get(body,"sample",220),dimension=get(body,"dimension",1),threshold=get(body,"threshold",nothing))))
        elseif path=="/api/sensitivity"
            return json_response(computed(() -> sensitivity(ds,cfg;resolutions=get(body,"resolutions",[6,10,14,18]),gains=get(body,"gains",[1.3,1.7,2.2]))))
        elseif path=="/api/clustering"
            return json_response(computed(() -> clustering_analysis(ds,cfg;k=get(body,"k",12),tau=get(body,"tau",0.2))))
        elseif path=="/api/timeseries"
            return json_response(computed(() -> timeseries_analysis(ds,body["column"];dimension=get(body,"dimension",3),delay=get(body,"delay",2),window=get(body,"window",60),step=get(body,"step",30))))
        elseif path=="/api/multiparameter"
            return json_response(computed(() -> multiparameter_analysis(ds,cfg;sample=get(body,"sample",24),dimension=get(body,"dimension",0))))
        elseif path=="/api/export/rows"
            csv=export_rows(ds,get(body,"selected",collect(1:rowcount(ds))))
            return HTTP.Response(200,["Content-Type"=>"text/csv; charset=utf-8","Content-Disposition"=>"attachment; filename=grupo.csv"],csv)
        end
        return json_response(Dict("error"=>"Endpoint não encontrado.");status=404)
    elseif method=="GET"
        files=Dict("/"=>"index.html","/app.js"=>"app.js","/style.css"=>"style.css","/research"=>"research.html")
        haskey(files,path) || return json_response(Dict("error"=>"Página não encontrada.");status=404)
        mime=endswith(path,".js") ? "text/javascript" : endswith(path,".css") ? "text/css" : "text/html"
        return HTTP.Response(200,["Content-Type"=>mime*"; charset=utf-8","X-Content-Type-Options"=>"nosniff",
            "Content-Security-Policy"=>"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"],read(joinpath(APP_ROOT,"web",files[path])))
    end
    json_response(Dict("error"=>"Método não permitido.");status=405)
end

"""Local REST handler. No filesystem paths or Julia code are accepted from clients."""
function handler(req)
    host=HTTP.header(req,"Host","")
    origin=HTTP.header(req,"Origin","")
    # Browser writes must originate from this application; local host binding is the default.
    if !isempty(origin) && origin != "http://"*host && origin != "https://"*host
        return json_response(Dict("error"=>"Origem da requisição não permitida.");status=403)
    end
    if !isempty(host) && !occursin(r"^(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$",host)
        return json_response(Dict("error"=>"Use o endereço local do Studio.");status=403)
    end
    try
        route(req)
    catch err
        if err isa ArgumentError || err isa KeyError || err isa DimensionMismatch
            return json_response(Dict("error"=>sprint(showerror,err));status=err isa KeyError ? 404 : 422)
        end
        @error "Studio request failed" exception=(err,catch_backtrace())
        json_response(Dict("error"=>"O cálculo falhou. Consulte o terminal Julia para os detalhes.");status=500)
    end
end

function serve(;port=8090)
    println("\nMapperStudio · http://localhost:$port\nCtrl+C para encerrar. Dados permanecem nesta máquina.\n")
    server=HTTP.serve!(handler,"127.0.0.1",port;verbose=false)
    try
        wait(server)
    catch err
        err isa InterruptException || rethrow()
        println("\nStudio encerrado.")
    finally
        close(server)
    end
end
