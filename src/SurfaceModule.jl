module SurfaceModule

# External Packages

# Internal Packages
using ..ToolModule

# Exports
export Surface
export Spline, ColourLaw, Component
export get_template

# CONSTANTS 
const COLOUR_LAW_PATH = "salt2_color_correction_final.dat.gz"
const COLOUR_DISPERSION_PATH = "salt2_color_dispersion.dat.gz"
const SPLINE_PATH = "pca_1_opt1_final.list.gz"


# n-dimensional colour law polynomial
# salt2_color_correction_final.dat.gz
mutable struct ColourLaw
    a::Vector{Float64} # Colour law components
    version_key::String
    version::Int64
    min_λ_key::String
    min_λ::Float64
    max_λ_key::String
    max_λ::Float64
end

function ColourLaw(path::AbstractString)
    lines = readpath(path)
    lines = [i for i in lines if length(split(i)) != 0] # Remove empty lines
    lines = [i for i in lines if !occursin("#", split(i)[1])] # Remove commented lines

    num_components = parse(Int64, lines[1]) # First line should be number of components
    components = parse.(Float64, lines[2:num_components+1]) # Get components
    @assert length(components) == num_components "Expected $num_components components, got $(length(components))"

    version_line = string.(split(lines[num_components+2]))
    @assert contains(version_line[1], "version") "Expected Salt2ExtincionLaw.version got \"$version_line\""
    version_key = version_line[1]
    version = parse(Int64, version_line[end])

    min_λ_line = string.(split(lines[num_components+3]))
    @assert contains(min_λ_line[1], "min_lambda") "Expected Salt2ExtinctionLaw.min_lambda got \"$min_λ_line\""
    min_λ_key = min_λ_line[1]
    min_λ = parse(Float64, min_λ_line[end])

    max_λ_line = string.(split(lines[num_components+4]))
    @assert contains(max_λ_line[1], "max_lambda") "Expected Salt2ExtinctionLaw.max_lambda got \"$max_λ_line\""
    max_λ_key = max_λ_line[1]
    max_λ = parse(Float64, max_λ_line[end])

    return ColourLaw(components, version_key, version, min_λ_key, min_λ, max_λ_key, max_λ)
end

# Wavelength Error
# salt2_color_dispersion.dat.gz
mutable struct ColourDispersion
    λ::Vector{Float64} # Wavelength
    σ::Vector{Float64} # Wavelength 
end

function ColourDispersion(path::AbstractString)
    lines = readpath(path)
    lines = [i for i in lines if length(split(i)) != 0] # Remove empty lines
    lines = [i for i in lines if !occursin("#", split(i)[1])] # Remove commented lines
    lines = [parse.(Float64, split(i)) for i in lines]

    λ = getindex.(lines, 1)
    σ = getindex.(lines, 2)

    return ColourDispersion(λ, σ)
end

mutable struct Component
    basis::String
    n_epochs::Int64
    n_wavelength::Int64
    phase_start::Float64
    phase_end::Float64
    wave_start::Float64
    wave_end::Float64
    values::Vector{Float64}
end

function Component(component_line::Vector{String})
    basis = component_line[1]
    n_epochs = parse(Int64, component_line[2])
    n_wavelengths = parse(Int64, component_line[3])
    phase_start = parse(Float64, component_line[4])
    phase_end = parse(Float64, component_line[5])
    wave_start = parse(Float64, component_line[6])
    wave_end = parse(Float64, component_line[7])
    values = map(x -> parse(Float64, x), component_line[8:end])
    return Component(basis, n_epochs, n_wavelengths, phase_start, phase_end, wave_start, wave_end, values)
end

# pca_1_opt1_final.list.gz
struct Spline
    components::Vector{Component}
end

function Spline(path::AbstractString)
    lines = readpath(path)
    lines = [i for i in lines if length(split(i)) != 0] # Remove empty lines
    lines = [i for i in lines if !occursin("#", split(i)[1])] # Remove commented lines

    num_components = parse(Int64, lines[1])
    components = Vector{Component}(undef, num_components)
    for i in 1:num_components
        components[i] = Component(string.(split(lines[i+1])))
    end
    return Spline(components)
end

mutable struct Surface
    name::String
    colour_law::ColourLaw
    colour_dispersion::ColourDispersion
    spline::Spline
    salt_info::String
end

function Surface(name::String, surface_path::AbstractString)
    surface_path = uncompress(surface_path)

    colour_law_path = joinpath(surface_path, COLOUR_LAW_PATH)
    colour_law = ColourLaw(colour_law_path)

    colour_dispersion_path = joinpath(surface_path, COLOUR_DISPERSION_PATH)
    colour_dispersion = ColourDispersion(colour_dispersion_path)

    spline_path = joinpath(surface_path, SPLINE_PATH)
    spline = Spline(spline_path)

    salt_info = gen_salt_info(colour_law)

    return Surface(name, colour_law, colour_dispersion, spline, salt_info)
end

function gen_salt_info(colour_law::ColourLaw)
    min_λ = colour_law.min_λ
    max_λ = colour_law.max_λ
    version = colour_law.version
    a = colour_law.a
    return """
    RESTLAMBDA_RANGE: $min_λ $max_λ
    COLORLAW_VERSION: $version
    COLORCOR_PARMAS: $min_λ $max_λ $(length(a)) $(join(a, " "))

    # TODO: Find out how to calculate this
    MAG_OFFSET: 0.27
    SIGMA_INT: 0.106
    COLOR_OFFSET: 0.0

    # TODO: Find out how to calculate this
    SEDFLUX_INTERP_OPT: 2  # 1=>linear,    2=>spline
    ERRMAP_INTERP_OPT:  1  # 0=snake off;  1=>linear  2=>spline
    ERRMAP_KCOR_OPT:    1  # 1/0 => on/off

    # TODO: Find out how to calculate this
    MAGERR_FLOOR:   0.005            # model-error floor
    MAGERR_LAMOBS:  0.0  2000  4000  # magerr minlam maxlam
    MAGERR_LAMREST: 0.1   100   200  # magerr minlam maxlam
    """
end

function reduced_λ(λ::Float64)
    wave_B = 4302.57
    wave_V = 5428.55
    return (λ - wave_B) / (wave_V - wave_B)
end

function derivative(α::Float64, colour_law::ColourLaw, r_λ::Float64)
    d = α
    for (e, a) in enumerate(colour_law.a)
        d += (e + 1) * a * (r_λ^e)
    end
    return d
end

function c_law(α::Float64, colour_law::ColourLaw, r_λ::Float64)
    d = α * r_λ
    for (e, a) in enumerate(colour_law.a)
        d += a * (r_λ^(e + 1))
    end
    return d
end

function get_colour_law(surface::SurfaceModule.Surface, λ_min::Float64=2000.0, λ_step::Float64=10.0, λ_max::Float64=9200.0)
    colour_law = surface.colour_law

    constant = 0.4 * log(10.0)

    c_λ_min = colour_law.min_λ
    c_r_λ_min = reduced_λ(c_λ_min)
    c_λ_max = colour_law.max_λ
    c_r_λ_max = reduced_λ(c_λ_max)

    #c_λ = λ_min:λ_max
    #c_r_λ = reduced_λ(c_λ)

    α = 1 - sum(colour_law.a)

    p_derivative_min = derivative(α, colour_law, c_r_λ_min)
    p_derivative_max = derivative(α, colour_law, c_r_λ_max)

    p_r_λ_min = c_law(α, colour_law, c_r_λ_min)
    p_r_λ_max = c_law(α, colour_law, c_r_λ_max)

    λ = λ_min:λ_step:λ_max
    r_λ = reduced_λ.(λ)

    p = zeros(length(r_λ))
    for (i, r) in enumerate(r_λ)
        if r < r_λ_min
            @inbounds p[i] = @. p_r_λ_min + p_derivative_min * (r - r_λ_min)
        elseif r > r_λ_max
            @inbounds p[i] = @. p_r_λ_max + p_derivative_max * (r - r_λ_max)
        else
            @inbounds p[i] = c_law(α, colour_law, r)
        end
    end

    C = 0.1

    A_λ = @. -p * C * constant
    A_λ_σ_plus = @. -(p + surface.colour_law_err.σ) * C * constant
    A_λ_σ_minus = @. -(p - surface.colour_law_err.σ) * C * constant

    return (λ, A_λ, A_λ_σ_plus, A_λ_σ_minus)
end

function split_index(index::Int64, component::Component)
    n_epochs = component.n_epochs
    index_phase = index % n_epochs
    index_wave = floor(Int64, index / n_epochs)
    return index_phase, index_wave
end

function phase_func(phase::Float64)
    return (-1.0 * (0.045 * phase)^3.0 + phase + 6.0 * (1.0 / (1.0 + exp(-0.5 * (phase + 18.0))) + 1.0 / (1.0 + exp(-0.3 * (phase))) + 1.0 / (1.0 + exp(-0.3 * (phase - 20.0)))))
end

function reducedEpoch(phase_min::Float64, phase_max::Float64, phase::Float64)
    phase_func_min = phase_func(phase_min)
    phase_func_max = phase_func(phase_max)
    number_of_parameters_for_phase = 14.0
    return number_of_parameters_for_phase * (phase_func(phase) - phase_func_min) / (phase_func_max - phase_func_min)
end

function λ_func(λ::Float64)
    return (1.0 / (1.0 + exp(-(λ - 4000.0) / 2000.0)))
end

function reducedLambda(λ_func_min::Float64, λ_func_max::Float64, λ::Float64)
    number_of_parameters_for_λ = 100.0
    return number_of_parameters_for_λ * (λ_func(λ) - λ_func_min) / (λ_func_max - λ_func_min)
end

function BSpline3(t::Float64, i::Int64)
    if (t < i) || (t > i + 3)
        return 0.0
    elseif t < i + 1
        return 0.5 * ((t - i)^2)
    elseif t < i + 2
        return 0.5 * ((i + 2 - t) * (t - i) + (t - i - 1) * (i + 3 - t))
    else
        return 0.5 * ((i + 3 - t)^2)
    end
end

function get_template(component::Component, phase::Float64)
    λ_min = component.wave_start
    λ_max = component.wave_end
    n_points = component.n_epochs * component.n_wavelength
    λ_step = floor((λ_max - λ_min) / n_points)
    λ = λ_min:λ_step:λ_max

    phase_start = component.phase_start
    phase_end = component.phase_end

    if !(phase_start <= phase <= phase_end)
        flux = zeros(length(λ))
    else
        λ_func_min = λ_func(λ_min)
        λ_func_max = λ_func(λ_max)
        reduced_phase = reducedEpoch(phase_start, phase_end, phase)
        flux = Vector{Float64}(undef, length(λ))
        for (i, w) in enumerate(λ)
            reduced_wave = reducedLambda(λ_func_min, λ_func_max, w)
            flux_val = 0.0
            for j in 1:n_points
                index_phase, index_wave = split_index(j - 1, component)
                interp = BSpline3(reduced_phase, index_phase) * BSpline3(reduced_wave, index_wave)
                @inbounds flux_val += interp * component.values[j]
            end
            @inbounds flux[i] = flux_val
        end
    end
    return (λ, flux)
end

end
