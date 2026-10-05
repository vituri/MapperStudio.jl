using Test, MapperStudio, JSON3, HTTP, Statistics, LinearAlgebra
const MS=MapperStudio

function circle_fixture(n=120)
    θ=2π.*(0:n-1)./n
    Dataset("Exact circle",["x","y","half"],Dict("x"=>Any[cos.(θ)...],"y"=>Any[sin.(θ)...],"half"=>Any[(θ.<π)...]))
end

@testset "Command-line options" begin
    @test MS.cli_options(String[]; env=Dict()).port == 8090
    @test MS.cli_options(String[]; env=Dict("MAPPER_STUDIO_PORT"=>"8091")).port == 8091
    @test MS.cli_options(["--port", "8092"]; env=Dict("MAPPER_STUDIO_PORT"=>"invalid")).port == 8092
    @test MS.cli_options(["--port=8093"]; env=Dict()).port == 8093
    @test MS.cli_options(["--help"]; env=Dict("MAPPER_STUDIO_PORT"=>"invalid")).action == :help
    @test MS.cli_options(["--version"]; env=Dict()).action == :version
    for args in (["--port"], ["--port", "0"], ["--port=65536"], ["--port=abc"], ["--port="], ["--unknown"])
        @test_throws ArgumentError MS.cli_options(args; env=Dict())
    end
end

@testset "Data integrity and preprocessing" begin
    ds=parse_csv("x,y,label\n1,3,A\n2,,B\n3,5,A\n";name="Fixture")
    @test ds.numeric==["x","y"]
    @test ds.data["y"][2]===nothing
    cfg=MS.config_for(ds,Dict("columns"=>["x","y"]))
    matrix,audit=MS.prepare(ds,cfg)
    @test vec(mean(matrix;dims=2))≈zeros(2)
    @test [std(matrix[i,:]) for i in 1:2]≈ones(2)
    @test audit[2]["imputed"]==1
    @test ds.data["y"][2]===nothing # no mutation of input
    @test_throws ArgumentError MS.prepare(ds,merge(cfg,Dict("missing"=>"reject")))
    @test_throws ArgumentError parse_csv("x\nNaN\n2\n3\n")
    @test_throws ArgumentError parse_csv("name\na\nb\nc\n")
    @test_throws ArgumentError parse_csv("x\n1\n2\n")
    @test_throws ArgumentError MS.config_for(ds,Dict("columns"=>["label"]))
    @test_throws ArgumentError MS.config_for(ds,Dict("columns"=>["x","x"]))
    @test_throws ArgumentError MS.config_for(ds,Dict("columns"=>[]))
    @test_throws ArgumentError MS.config_for(ds,["bad"])
    @test_throws ArgumentError MS.config_for(ds,Dict("resolution"=>41))
    @test_throws ArgumentError MS.config_for(ds,Dict("gain"=>Inf))
    @test_throws ArgumentError MS.config_for(ds,Dict("cluster"=>"kmeans","metric"=>"cosine"))
    original=MS.prepare(ds,merge(cfg,Dict("scaling"=>"none")))[1]
    @test original≈[1 2 3;3 4 5]
    for mode in ["standard","robust","minmax","none"]
        @test all(isfinite,MS.prepare(ds,merge(cfg,Dict("scaling"=>mode)))[1])
    end
    @test demo_dataset("diabetes").name=="Diabetes · Reaven & Miller"
    @test MS.rowcount(demo_dataset("diabetes"))==145
    @test_throws ArgumentError demo_dataset("unknown")
end

@testset "Gain and equalization references" begin
    for gain in (1.,1.3,2.,3.,5.),r in (2,7,12)
        intervals=MS.cover_intervals([0.,1.],r,gain)
        @test length(intervals)==r
        @test first(intervals).a==0
        @test last(intervals).b==1
        a,b=intervals[1],intervals[2]
        @test (a.b-b.a)/(a.b-a.a)≈1-1/gain atol=1e-14
        @test all(v->any(i->i.a-1e-14<=v<=i.b+1e-14,intervals),range(0,1;length=101))
    end
    @test length(MS.cover_intervals(fill(2.,10),12,2.))==1
    @test MS.equalized([0.,0.,1.,2.])≈[1/6,1/6,2/3,1.]
end

@testset "Mapper membership and graph correctness" begin
    ds=circle_fixture()
    cfg=Dict("columns"=>["x","y"],"scaling"=>"none","lens1"=>"column:x","lens2"=>"none",
        "resolution"=>8,"gain"=>1.4,"cluster"=>"single","radius"=>0.25)
    model=analyze(ds,cfg)
    @test model["summary"]["coverage"]==1
    @test model["summary"]["components"]==1
    @test model["summary"]["graph_cycles"]==1
    nodes=model["nodes"];edges=model["edges"]
    actual=Set((e["source"],e["target"]) for e in edges)
    expected=Set((i,j) for i in eachindex(nodes) for j in i+1:length(nodes) if !isempty(intersect(nodes[i]["members"],nodes[j]["members"])))
    @test actual==expected
    @test unique(sort(vcat([n["members"] for n in nodes]...)))==1:120
    for e in edges
        @test e["shared"]==length(intersect(nodes[e["source"]]["members"],nodes[e["target"]]["members"]))
    end
    for kind in ("firstempty","dbscan","single","complete","average","kmeans","trivial")
        result=analyze(ds,merge(cfg,Dict("cluster"=>kind)))
        @test result["summary"]["coverage"]==1
        @test all(n->!isempty(n["members"]),result["nodes"])
    end
    a=analyze(ds,merge(cfg,Dict("cluster"=>"kmeans")));b=analyze(ds,merge(cfg,Dict("cluster"=>"kmeans")))
    @test [n["members"] for n in a["nodes"]]==[n["members"] for n in b["nodes"]]
    ball=analyze(ds,merge(cfg,Dict("algorithm"=>"ball","ball_radius"=>0.4)))
    @test ball["summary"]["coverage"]==1
    @test_throws ArgumentError analyze(ds,merge(cfg,Dict("algorithm"=>"ball","ball_radius"=>1e-6,"max_landmarks"=>3)))
    @test_throws ArgumentError sensitivity(ds,Dict("algorithm"=>"ball"))
    sweep=sensitivity(ds,cfg;resolutions=[6,8],gains=[1.4,2.])
    @test length(sweep["results"])==4
    @test all(r->r["coverage"]==1,sweep["results"])
    result=analyze(ds,merge(cfg,Dict("nerve"=>"jaccard","edge_threshold"=>0.2)))
    for edge in result["edges"]
        a=result["nodes"][edge["source"]]["members"];b=result["nodes"][edge["target"]]["members"]
        @test length(intersect(a,b))/length(union(a,b))>=0.2
    end
    # DBSCAN noise must not connect distant observations into one node.
    isolated=MS.SingletonNoiseDBSCAN(0.01,3,MS.Euclidean())(MS.MetricSpaces.EuclideanSpace([[0.],[10.],[20.]]))
    @test length(unique(isolated))==3
end

@testset "Lenses, geometry and provenance" begin
    ds=circle_fixture(40)
    for metric in ("euclidean","manhattan","chebyshev","cosine","correlation")
        context=MS.build_context(ds,Dict("columns"=>metric=="correlation" ? ["x","y","half"] : ["x","y"],"scaling"=>"none","metric"=>metric))
        @test context.d≈context.d'
        @test all(isfinite,context.d)
        @test all(==(0),diag(context.d))
    end
    for lens in ("pca1","pca2","mds1","mds2","diffusion1","diffusion2","eccentricity","eccentricity_inf","density","gaussian","norm","index","column:x")
        context=MS.build_context(ds,Dict("columns"=>["x","y"],"lens1"=>lens,"lens2"=>"none"))
        @test length(context.lenses[1])==40
        @test all(isfinite,context.lenses[1])
    end
    cfg=MS.config_for(ds,Dict("columns"=>["x","y"],"scaling"=>"none"));mat=MS.prepare(ds,cfg)[1]
    projection=MS.mds_projection(MS.distance_matrix(mat,"euclidean"))
    @test MS.pairwise(MS.Euclidean(),permutedims(projection);dims=2)≈MS.distance_matrix(mat,"euclidean") atol=1e-7
    @test MS.landmarks(MS.distance_matrix(mat,"euclidean"),10)==MS.landmarks(MS.distance_matrix(mat,"euclidean"),10)
end

@testset "Explain independent statistical fixtures" begin
    # scipy.stats.ks_2samp reference values, including ties.
    @test MS.ks_statistic([0,0,1,1],[0,1,2,2])==0.5
    @test MS.ks_statistic([1,2,3,4],[10,11,12,13])==1
    @test MS.ks_statistic([1,1,1],[1,1,1])==0
    @test MS.categorical_distance(["a","a"],["b","b"])==1
    @test MS.bh_adjust([.01,.04,.03,.002])≈[.02,.04,.04,.008]
    n=24;ds=Dataset("Separated",["signal","constant","label"],Dict("signal"=>Any[zeros(12)...,ones(12)...],"constant"=>Any[fill(2.,n)...],"label"=>Any[fill("a",12)...,fill("b",12)...]))
    a=explain(ds,vcat(1:12,1:12);permutations=199,seed=9)
    b=explain(ds,collect(1:12);permutations=199,seed=9)
    @test a==b
    @test a["selected_n"]==12
    @test a["reference_n"]==12
    @test first(a["features"])["score"]==1
    @test first(a["features"])["q"]<=0.05
    @test all(r->1/200<=r["p"]<=r["q"]<=1,a["features"])
    constant=only(filter(r->r["column"]=="constant",a["features"]))
    @test constant["p"]==1
    @test constant["effect"]===nothing
    overlapping=explain(ds,collect(1:12);reference=collect(8:24),permutations=19)
    @test overlapping["reference_n"]==12
    @test_throws ArgumentError explain(ds,[1,1])
    @test_throws ArgumentError explain(ds,[0,2])
    @test_throws ArgumentError explain(ds,[1,2];reference=[1,2,3])
end

@testset "Persistent homology and advanced TDA" begin
    ds=circle_fixture(60);cfg=Dict("columns"=>["x","y"],"scaling"=>"none")
    ph=persistence_analysis(ds,cfg;sample=60)
    @test ph["sample_n"]==60
    @test sort(ph["landmarks"])==1:60
    @test count(b->b["dimension"]==0&&isnothing(b["death"]),ph["bars"])==1
    h1=filter(b->b["dimension"]==1&&!isnothing(b["persistence"]),ph["bars"])
    @test maximum(b["persistence"] for b in h1)>1.5 # analytic unit-circle loop
    @test ph["betti"][1]["values"][end]==1
    @test ph["betti"][2]["values"][end]==0
    @test_throws ArgumentError persistence_analysis(ds,cfg;sample=81,dimension=2)
    @test_throws ArgumentError persistence_analysis(ds,cfg;selected=[1,2])
    duplicates=Dataset("Identical",["x"],Dict("x"=>Any[1,1,1]))
    duplicateph=persistence_analysis(duplicates;sample=3)
    @test duplicateph["sample_n"]==1
    @test duplicateph["zero_distance_collapsed"]==2
    @test length(duplicateph["bars"])==1
    clusters=clustering_analysis(ds,cfg;k=6,tau=.2)
    @test sort(unique(vcat([g["rows"] for g in clusters["groups"]]...)))==1:60
    ts=timeseries_analysis(ds,"x";dimension=3,delay=2,window=20,step=20)
    @test ts["embedding_n"]==56
    @test ts["windows"][1]["source_stop"]==24
    @test_throws ArgumentError timeseries_analysis(ds,"x";window=100)
    multi=multiparameter_analysis(ds,cfg;sample=10)
    @test size(reduce(hcat,multi["hilbert"]))==(10,10)
    @test multi["hilbert"][end][end]==1
    @test_throws ArgumentError multiparameter_analysis(ds,cfg;sample=29)
    # Analytical cubical annulus: one loop born at 0, filled at 1, final Euler = 1.
    A=ones(9,9);A[2:8,2:8].=0;A[3:7,3:7].=1
    image=image_analysis([collect(A[i,:]) for i in axes(A,1)])
    loop=only(filter(b->b["dimension"]==1,image["bars"]))
    @test loop["birth"]==0
    @test loop["death"]==1
    @test image["euler"]["values"][1]==0
    @test image["euler"]["values"][end]==1
    for filtration in ("height","radial","dilation","erosion","signed_distance")
        result=image_analysis([collect(A[i,:]) for i in axes(A,1)];filtration)
        @test !isempty(result["bars"])
        @test all(isfinite,result["euler"]["values"])
    end
    @test_throws ArgumentError image_analysis([[0.,1.],[0.]])
end

@testset "REST contract and local boundaries" begin
    request(path,body)=handler(HTTP.Request("POST",path,["Host"=>"localhost:8090","Content-Type"=>"application/json"],JSON3.write(body)))
    @test handler(HTTP.Request("GET","/api/health")).status==200
    home=handler(HTTP.Request("GET","/"))
    @test home.status==200
    @test occursin("default-src 'self'",HTTP.header(home,"Content-Security-Policy"))
    @test handler(HTTP.Request("GET","/research")).status==200
    @test handler(HTTP.Request("GET","/../../Project.toml")).status==404
    @test handler(HTTP.Request("POST","/api/demo",["Host"=>"localhost:8090","Origin"=>"https://elsewhere.test"],"{}")).status==403
    @test handler(HTTP.Request("GET","/api/health",["Host"=>"attacker.test"])).status==403
    response=request("/api/import",Dict("csv"=>"x,y\n0,0\n1,0\n0,1\n1,1\n"))
    @test response.status==200
    ds=JSON3.read(String(response.body),Dict{String,Any});id=ds["id"]
    result=request("/api/mapper",Dict("dataset_id"=>id,"config"=>Dict("cluster"=>"trivial")))
    @test result.status==200
    @test JSON3.read(String(result.body))["summary"]["coverage"]==1
    @test request("/api/mapper",Dict("dataset_id"=>id,"config"=>Dict("gain"=>0))).status==422
    @test request("/api/mapper",Dict("dataset_id"=>"not-found")).status==404
    @test request("/api/export/rows",Dict("dataset_id"=>id,"selected"=>[1,1,2])).status==200
    exported=request("/api/export/rows",Dict("dataset_id"=>id,"selected"=>[1,1,2]))
    @test count(==('\n'),String(exported.body))==3
    @test handler(HTTP.Request("POST","/api/import",[],"not-json")).status==422
end
