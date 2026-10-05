const CLI_HELP = """
MapperStudio 0.1.0 — Mapper e análise topológica no navegador

Uso: mapperstudio [--port PORTA]

  --port PORTA    Porta local (padrão: MAPPER_STUDIO_PORT ou 8090)
  -h, --help     Mostrar esta ajuda
  -v, --version  Mostrar a versão

Abra http://localhost:8090 após iniciar. Ctrl+C encerra o servidor.
"""

function cli_port(value)
    port = tryparse(Int, value)
    !isnothing(port) && 1 <= port <= 65535 ||
        throw(ArgumentError("A porta deve ser um inteiro entre 1 e 65535."))
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
            i < length(args) || throw(ArgumentError("--port requer uma porta."))
            i += 1
            port = args[i]
        elseif startswith(arg, "--port=")
            port = arg[8:end]
        else
            throw(ArgumentError("Opção desconhecida: $arg. Use --help."))
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
        Base.exit_on_sigint(false)
        serve(; port=options.port)
    end
    return 0
end
