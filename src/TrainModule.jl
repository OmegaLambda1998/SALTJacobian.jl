module TrainModule

# External Packages
using CodecZlib 

# Internal Packages
using ..ToolModule
using ..TrainoptModule
using ..SurfaceModule
using ..JacobianModule

# Exports
export train_surface
export save_surface

# CONSTANTS 
const COLOUR_LAW_PATH = "salt2_color_correction_final.dat.gz"
const COLOUR_DISPERSION_PATH = "salt2_color_dispersion.dat.gz"
const SPLINE_PATH = "pca_1_opt1_final.list.gz"

function train_surface(trainopt::String, jacobian::Jacobian, name::String, wave_equiv::Vector{String}=Vector{String}(), mag_equiv::Vector{String}=Vector{String}())
    base_surface = deepcopy(jacobian.base_surface)
    trainopts = parse_trainopts(string.(split(trainopt)), wave_equiv, mag_equiv)
    cl = base_surface.colour_law.a
    for trainopt in trainopts
        trainopt_name = join([trainopt.type, trainopt.instrument, trainopt.filter], "-")
        if !(trainopt_name in jacobian.trainopt_names)
            error("Trainopt $(split(trainopt_name, "-")) not in jacobian. Possible options are $(split.(jacobian.trainopt_names, "-"))")
        end
        jacobian_scale = jacobian.trainopts[trainopt_name].scale
        trainopt_scale = trainopt.scale
        scale = trainopt_scale / jacobian_scale
        # ∇splines = base_surface - perturbed_surface
        # ∴ perturbed_surface = base_surface - ∇spline_1
        ∇splines = jacobian.∇splines[trainopt_name]
        for (i, ∇spline) in enumerate(∇splines)
            base_surface.spline.components[i].values -= ∇spline .* scale
        end
        # ∇colour_law = base_surface - perturbed_surface
        # ∴ perturbed_surface = base_surface - ∇colour_law
        ∇colour_law = jacobian.∇colour_law[trainopt_name]
        base_surface.colour_law.a -= ∇colour_law .* scale
    end
    return base_surface
end

function save_spline(spline::Spline, path::AbstractString)
    spline_file = open(GzipDecompressorStream, path, "r") do io
        return readlines(io)
    end
    for (i, component) in enumerate(spline.components)
        spline_file[i + 1] = "$(component.basis) $(component.n_epochs) $(component.n_wavelength) $(component.phase_start) $(component.phase_end) $(component.wave_start) $(component.wave_end) $(join(component.values, " "))"
    end
    open(GzipCompressorStream, path, "w") do io
        write(io, join(spline_file, "\n"))
    end
end

function save_colour_law(colour_law::ColourLaw, path::AbstractString)
    colour_law_file = open(GzipDecompressorStream, path, "r") do io
        return readlines(io)
    end
    for (i, a) in enumerate(colour_law.a)
        colour_law_file[i + 1] = string(a)
    end
    open(GzipCompressorStream, path, "w") do io
        write(io, join(colour_law_file, "\n"))
    end
end

function save_surface(surface::Surface, output::AbstractString)
    surface_path = uncompress(output)
    name = split(splitdir(output)[end], ".")[1]
    tmpdir = joinpath(splitdir(surface_path)[1], name)
    mv(surface_path, tmpdir)
     
    
    spline_path = joinpath(tmpdir, SPLINE_PATH)
    save_spline(surface.spline, spline_path)

    colour_law_path = joinpath(tmpdir, COLOUR_LAW_PATH)
    save_colour_law(surface.colour_law, colour_law_path)

    compress(tmpdir, output; parent=true)
end

end

