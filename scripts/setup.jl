using Pkg
const APP_ROOT = realpath(joinpath(@__DIR__, ".."))
Pkg.activate(APP_ROOT)
Pkg.instantiate()
Pkg.precompile(; strict=true)
println("\nReady: julia --project=$(APP_ROOT) -m MapperStudio")
