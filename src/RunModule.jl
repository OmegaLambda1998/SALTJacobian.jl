module RunModule

# External Packages

# Internal Packages
include(joinpath(@__DIR__, "ToolModule.jl"))
using .ToolModule

include(joinpath(@__DIR__, "TrainoptModule.jl"))
using .TrainoptModule

include(joinpath(@__DIR__, "SurfaceModule.jl"))
using .SurfaceModule

include(joinpath(@__DIR__, "JacobianModule.jl"))
using .JacobianModule

include(joinpath(@__DIR__, "TrainModule.jl"))
using .TrainModule

# Exports
export run_SALTJacobian
export Jacobian

function jacobian_stage(option::Dict{String,Any}, config::Dict{String,Any})
    if "JACOBIAN_PATH" in keys(option)
        input = option["JACOBIAN_PATH"]
        if !isabspath(input)
            input = joinpath(config["BASE_PATH"], input)
        end
        input = abspath(input)
        jacobian = load_jacobian(input)
        name = get(option, "NAME", nothing)
        if !isnothing(name)
            jacobian.name = name
        end
        base_surface_output = joinpath(config["OUTPUT_PATH"], "TRAINOPT000")
        if isfile(jacobian.base_surface_path)
            base_surface_output = base_surface_output * ".tar.gz"
        end
        @info "Saving base surface to $base_surface_output"
        if jacobian.base_surface_path != base_surface_output
            cp(jacobian.base_surface_path, base_surface_output, force=true)
        end
        if isdir(base_surface_output)
            @info "Compressing $base_surface_output"
            compress(base_surface_output, base_surface_output * ".tar.gz"; parent=true)
            rm(base_surface_output, recursive=true, force=true)
            jacobian.base_surface_path = base_surface_output * ".tar.gz"
        end
        jacobian_output = joinpath(config["OUTPUT_PATH"], jacobian.name * ".jld2")
        @info "Saving Jacobian to $jacobian_output"
        cp(input, jacobian_output, force=true)
    elseif "TRAINED_SURFACES" in keys(option)
        jacobian = Jacobian(option, config)
        if !occursin("jacobian", jacobian.name)
            jacobian.name *= "_jacobian"
        end
        base_surface_output = joinpath(config["OUTPUT_PATH"], "TRAINOPT000")
        if isfile(jacobian.base_surface_path)
            base_surface_output = base_surface_output * ".tar.gz"
        end
        @info "Saving base surface to $base_surface_output"
        cp(jacobian.base_surface_path, base_surface_output, force=true)
        if isdir(base_surface_output)
            @info "Compressing $base_surface_output"
            compress(base_surface_output, base_surface_output * ".tar.gz"; parent=true)
            rm(base_surface_output, recursive=true, force=true)
            jacobian.base_surface_path = base_surface_output * ".tar.gz"
        end
        jacobian_output = joinpath(config["OUTPUT_PATH"], jacobian.name * ".jld2")
        save_jacobian(jacobian, jacobian_output)
    else
        error("Keys TRAINED_SURFACES or JACOBIAN_PATH not found, can not create Jacobian matrix without one or the other.")
    end
    return jacobian
end

function surfaces_stage(options::Vector{Dict{String,Any}}, jacobian::Jacobian, config::Dict{String,Any})
    surfaces = Vector{Surface}()
    for option in options
        output_name = option["NAME"]
        output_path = joinpath(config["OUTPUT_PATH"], output_name)
        mkpath(output_path)
        base_surface_output = joinpath(output_path, "TRAINOPT000")
        if isfile(jacobian.base_surface_path)
            base_surface_output = base_surface_output * ".tar.gz"
        end
        @info "Saving base surface to $base_surface_output"
        cp(jacobian.base_surface_path, base_surface_output, force=true)
        jacobian.base_surface_path = base_surface_output
        if isdir(base_surface_output)
            @info "Compressing $base_surface_output"
            compress(base_surface_output, base_surface_output * ".tar.gz", parent=true)
            rm(base_surface_output, recursive=true, force=true)
            jacobian.base_surface_path = base_surface_output * ".tar.gz"
        end
        i = 1
        if "TRAINOPTS" in keys(option)
            trainopts = option["TRAINOPTS"]
            mode = get(option, "MODE", "seperate")
            mag_equiv = get(option, "SURVEY_LIST_SAMEMAGSYS", Vector{String}())
            wave_equiv = get(option, "SURVEY_LIST_SAMEFILTER", Vector{String}())
            if mode == "seperate"
                for trainopt in trainopts
                    name = "TRAINOPT$(lpad(i, 3, "0"))"
                    @info "Creating surface for $name, with trainopt \"$trainopt\""
                    surface = train_surface(trainopt, jacobian, name, wave_equiv, mag_equiv)
                    output = joinpath(output_path, "$name.tar.gz")
                    cp(jacobian.base_surface_path, output, force=true)
                    save_surface(surface, output)
                    i += 1
                end
            elseif mode == "combine"
                name = "TRAINOPT$(lpad(i, 3, "0"))"
                trainopt = join(trainopts, " ")
                @info "Creating surface for $name with trainopt \"$trainopt\""
                surface = train_surface(trainopt, jacobian, name, wave_equiv, mag_equiv)
                output = joinpath(output_path, "$name.tar.gz")
                cp(jacobian.base_surface_path, output, force=true)
                save_surface(surface, output)
                i += 1
            else
                error("Unknown trainopt mode $mode. Options are 'seperate' or 'combined'")
            end
        elseif "SURFACE_PATH" in keys(option)
            input = option["SURFACE_PATH"]
            if !isabspath(input)
                input = joinpath(config["BASE_PATH"], input)
            end
            input = abspath(input)
            surface = load_surface(input)
            output = joinpath(config["OUTPUT_PATH"], "TRAINOPT$(lpad(i, 3, "0")).jld2")
            cp(input, output, force=true)
        else
            error("Keys TRAINOPTS or JACOBIAN_PATH not found, can not create Jacobian matrix without one or the other.")
        end
        push!(surfaces, surface)
    end
    return surfaces
end

function run_SALTJacobian(toml::Dict{String,Any})
    config = toml["GLOBAL"]

    # Create / Load Jacobian
    if "JACOBIAN" in keys(toml)
        jacobian = jacobian_stage(toml["JACOBIAN"], config)
    else
        jacobian = nothing
    end

    # Create approximate surfaces
    if "SURFACES" in keys(toml)
        if isnothing(jacobian)
            error("Can not approximate surfaces without a jacobian! Please define one via [[ jacobian ]]")
        end
        surfaces = surfaces_stage(toml["SURFACES"], jacobian, config)
    else
        surfaces = Vector{Surface}()
    end

    # Plotting and comparison
    if "ANALYSIS" in keys(toml)
        analysis_stage(toml["ANALYSIS"], jacobians, surfaces, salt_surfaces, config)
    end
    return jacobian, surfaces
end

end
