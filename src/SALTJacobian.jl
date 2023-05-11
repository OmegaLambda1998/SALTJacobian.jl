module SALTJacobian

# External packages
using Pkg
using TOML
using BetterInputFiles 
using ArgParse
import OrderedCollections.OrderedDict

# Internal Packages

# Exports
export main 

function julia_main()::Cint
    try
        main()
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

function get_args()
    return get_args(ARGS)
end

function get_args(args)
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--verbose", "-v"
            help = "Increase level of logging verbosity."
            action = :store_true
        "--batch"
            help = "Whether or not we're running in batch mode."
            action = :store_true
    end
    add_arg_group!(s, "Batch Mode")
    @add_arg_table! s begin
        "--jacobian", "-j"
            help = "Path to pretrained Jacobian matrix."
            default = nothing
        "--base_surface", "-b"
            help = "Path to base (unperturbed) surface."
            default = nothing
        "--output", "-o"
            help = "Path to output directory."
            default = nothing
        "--yaml", "-y"
            help = "Path to output yaml file. Will create a .yaml file for SNANA compliance."
            default = nothing
        "--trainopt", "-t"
            help = "TRAINOPT string, as used by submit_batch."
            default = nothing
    end
    add_arg_group!(s, "Input Mode")
    @add_arg_table! s begin
        "input"
            help = "Path to .toml file."
            default = nothing 
    end
    return parse_args(args, s)
end

function main()
    return main(ARGS)
end

function main(args::Vector{String})
    Pkg.instantiate()
    args = get_args(args)
    verbose = args["verbose"]
    batch_mode = args["batch"]
    # Load run module based on batch_mode so that we can avoid loading unecessary packages such as plotting.
    # The run module files include their own using statements.
    if batch_mode
        @info "Running in batch mode"
        include(joinpath(@__DIR__, "BatchRunModule.jl"))

        yaml_path = args["yaml"]
        if isnothing(yaml_path)
            throw(ArgumentError("Must specify a yaml path via --yaml/-y when in batch mode"))
        end
        try
            # Load in arguments 
            output_path = args["output"]
            if isnothing(output_path)
                throw(ArgumentError("Must specify an output directory via --output/-o when in batch mode"))
            end
            jacobian_path = args["jacobian"]
            if isnothing(jacobian_path)
                throw(ArgumentError("Must specify a pretrained jacobian matrix via --jacobian/-j when in batch mode"))
            end
            if !isfile(jacobian_path)
                throw(ArgumentError("Pretrained jacobian matrix $jacobian_path does not exist"))
            end
            base_surface = args["base_surface"]
            if isnothing(base_surface)
                throw(ArgumentError("Must specify a base (unperturbed) surface via --base/-b when in batch mode"))
            end
            if !isdir(base_surface)
                throw(ArgumentError("Base surface $base_surface does not exist"))
            end
            trainopt = args["trainopt"]
            if isnothing(trainopt)
                throw(ArgumentError("Must specify trainopt via --trainopt/-t when in batch mode"))
            end

            # Prepare TOML
            global_dict = Dict("base_path" => "./", "output_path" => output_path, "logging" => false)
            jacobian_dict = Dict("path" => jacobian_path)
            surface_dict = Dict("base_surface" => base_surface, "trainopt" => trainopt)
            toml = Dict("global" => global_dict, "jacobian" => [jacobian_dict], "surface" => [surface_dict])
            temp_toml = tempname() * ".toml"
            open(temp_toml, "w") do io
                TOML.print(io, toml)
            end
            toml = setup_input(temp_toml, verbose)

            # Run SALTJacobian
            num_trainopts = Base.invokelatest(batch_run_SALTJacobian, toml)
            open(yaml_path, "w") do io
                write(io, "ABORT_IF_ZERO: $num_trainopts # Number of successful trainopts")
            end
            return toml
        catch e
            open(yaml_path, "w") do io
                write(io, "ABORT_IF_ZERO: 0\nERROR: $e")
            end
            throw(e)
        end
    else
        @info "Running in input mode"
        include(joinpath(@__DIR__, "RunModule.jl"))

        toml_path = args["input"]
        if isnothing(toml_path)
            throw(ArgumentError("If not working in batch mode, must specify an input file!"))
        end
        paths = OrderedDict{String, Tuple{String, String}}(
            "jacobian_path" => ("base_path", "Jacobian"),
            "surfaces_path" => ("base_path", "Surfaces"),
            "salt_surfaces_path" => ("base_path", "SALT_Surfaces"),
            "analysis_path" => ("base_path", "Analysis")
        )
        toml = setup_input(toml_path, verbose)
        Base.invokelatest(run_SALTJacobian, toml)
        return toml
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end
