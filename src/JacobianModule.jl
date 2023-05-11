module JacobianModule

# External Packages
import BetterInputFiles.IOModule.load_inputfile
using FileIO
using JLD2

# Internal Packages
using ..ToolModule
using ..TrainoptModule
using ..SurfaceModule

# Exports
export Jacobian
export load_jacobian
export save_jacobian

# CONSTANTS
SUBMIT_INFO = "SUBMIT.INFO"
OUTPUT_TRAIN = "OUTPUT_TRAIN"


mutable struct Jacobian
    name::String
    trainopt_names::Vector{String}
    trainopts::Dict{String,Trainopt}
    ∇splines::Dict{String,Vector{Vector{Float64}}}
    ∇colour_law::Dict{String,Vector{Float64}}
    base_surface::Surface
    base_surface_path::AbstractString
end

function Jacobian(options::Dict{String,Any}, config::Dict{String,Any})
    name = get(options, "NAME", "jacobian")
    @info "Creating Jacobian $name"
    base_path = config["BASE_PATH"]
    trained_surfaces_path = options["TRAINED_SURFACES"]
    if !isabspath(trained_surfaces_path)
        trained_surfaces_path = abspath(joinpath(base_path, trained_surfaces_path))
    end
    if !isdir(trained_surfaces_path)
        if !isfile(trained_surfaces_path)
            error("Trained Surface path: $trained_surfaces_path does not exist")
        else
            trained_surfaces_path = uncompress(trained_surfaces_path)
        end
    end
    surface_output = joinpath(trained_surfaces_path, OUTPUT_TRAIN)
    submit_info = load_inputfile(joinpath(trained_surfaces_path, SUBMIT_INFO), "yaml")
    trainopt_list = submit_info["TRAINOPT_OUT_LIST"]
    @show trainopt_list
    mag_equiv = submit_info["SURVEY_LIST_SAMEMAGSYS"]
    wave_equiv = submit_info["SURVEY_LIST_SAMEFILTER"]

    trainopt_names = Vector{String}()
    surfaces = Dict{String,Surface}()
    trainopts = Dict{String,Trainopt}()

    base_surface = nothing
    base_surface_path = nothing
    #TODO Replace with ProgressBars
    for (i, trainopt_details) in enumerate(trainopt_list)
        @info "Evaluating TRAINOPT$(lpad(i - 1, 3, "0"))"
        surface_name = trainopt_details[1]
        surface_path = joinpath(surface_output, surface_name)
        trainopt = Trainopt(trainopt_details[end])
        trainopt_name = join([trainopt.type, trainopt.instrument, trainopt.filter], "-")
        if !isdir(surface_path)
            surface_path = surface_path * ".tar.gz"
            if !isfile(surface_path)
                error("Surface path $surface_path does not exist")
            else
                surface_path = uncompress(surface_path)
            end
        end
        if trainopt_details[end] == ""
            base_name = "BASE_SURFACE"
            base_surface = Surface(base_name, surface_path)
            base_surface_path = surface_path
        else
            surface = Surface(surface_name, surface_path)
            push!(trainopt_names, trainopt_name)
            surfaces[trainopt_name] = surface
            trainopts[trainopt_name] = trainopt
        end
    end
    if isnothing(base_surface)
        error("No base surface found!")
    end
    ∇splines = Dict{String,Vector{Vector{Float64}}}(name => [base_surface.spline.components[i].values - surfaces[name].spline.components[i].values for i in 1:length(base_surface.spline.components)] for name in trainopt_names)
    ∇colour_law = Dict{String,Vector{Float64}}(name => base_surface.colour_law.a - surfaces[name].colour_law.a for name in trainopt_names)
    @show trainopt_names
    return Jacobian(name, trainopt_names, trainopts, ∇splines, ∇colour_law, base_surface, base_surface_path)
end

function load_jacobian(input::AbstractString)
    @info "Loading Jacobian from $input"
    d = load(input)
    val = [d[string(key)] for key in fieldnames(Jacobian)]
    return Jacobian(val...)
end

function save_jacobian(jacobian::Jacobian, output_path::AbstractString)
    @info "Saving $(jacobian.name) Jacobian to $output_path"
    save(output_path, Dict(string(key) => getfield(jacobian, key) for key in fieldnames(Jacobian)))
end

end
