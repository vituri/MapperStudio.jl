module MapperStudio

using CSV, Dates, Distances, Graphs, HTTP, JSON3, LinearAlgebra, Random, Statistics, UUIDs
import Clustering
import MetricSpaces
import TDAmapper
import TDARipserer
import TDAPersistenceDiagrams
import ToMATo

# Bundle the JuliaTDA reference implementation until it is published separately.
include("../vendor/MultiparameterPersistence/src/MultiparameterPersistence.jl")

const APP_ROOT = realpath(joinpath(@__DIR__, ".."))
const MAX_ROWS = 3000
const MAX_COLUMNS = 80
const MAX_BYTES = 20 * 1024 * 1024

include("data.jl")
include("analysis.jl")
include("explain.jl")
include("tda.jl")
include("server.jl")
include("cli.jl")

export Dataset, parse_csv, demo_dataset, dataset_summary, analyze, explain,
       persistence_analysis, sensitivity, clustering_analysis, timeseries_analysis,
       multiparameter_analysis, image_analysis, serve, handler

end
