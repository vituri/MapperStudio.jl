const CLI_HELP = """
MapperStudio 0.1.0 — Mapper and topological analysis in your browser

Usage: mapperstudio [--port PORT]

  --port PORT     Local port (default: MAPPER_STUDIO_PORT or 8090)
  -h, --help     Show this help
  -v, --version  Show the version

Open http://localhost:8090 after starting. Ctrl+C stops the server.
"""

function cli_port(value)
    port = tryparse(Int, value)
    !isnothing(port) && 1 <= port <= 65535 ||
        throw(ArgumentError("The port must be an integer between 1 and 65535."))
    port
end

function cli_options(args; env=ENV)
    port = get(env, "MAPPER_STUDIO_PORT", "8090")
    i = 1
    while i <= length(args)
        arg = args[i]
        arg in ("-h", "--help") && return (; action=:help, port=nothing)
        arg in ("-v", "--version") && return (; action=:version, port=nothing)
        if arg == "--port"
            i < length(args) || throw(ArgumentError("--port requires a port number."))
            i += 1
            port = args[i]
        elseif startswith(arg, "--port=")
            port = arg[8:end]
        else
            throw(ArgumentError("Unknown option: $arg. Use --help."))
        end
        i += 1
    end
    (; action=:serve, port=cli_port(port))
end

function (@main)(args)
    options = try
        cli_options(args)
    catch err
        err isa ArgumentError || rethrow()
        println(stderr, "MapperStudio: ", err.msg)
        return 2
    end
    if options.action == :help
        print(CLI_HELP)
    elseif options.action == :version
        println("MapperStudio 0.1.0")
    else
        # With -m, Julia runs main in a separate task. Let SIGINT exit normally;
        # serve registers cleanup instead of throwing into the scheduler task.
        Base.exit_on_sigint(true)
        serve(; port=options.port)
    end
    return 0
end
