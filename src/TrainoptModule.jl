module TrainoptModule

# External Packages

# Internal Packages

# Exports
export Trainopt
export parse_trainopts

struct Trainopt
    type::String
    instrument::String
    filter::String
    scale::Float64
end

function Trainopt(trainopt::String, wave_equiv::Vector{String}=Vector{String}(), mag_equiv::Vector{String}=Vector{String}())
    if trainopt == ""
        return Trainopt("", "", "", 0.0)
    else
        type, instrument, filter, scale = split(trainopt, " ")
        if type == "WAVESHIFT"
            equiv = wave_equiv
        elseif type == "MAGSHIFT"
            equiv = mag_equiv
        else
            error("Unknown trainopt type $type")
        end
        if instrument in equiv
            @debug "$instrument is equivalent to $(equiv[1]) for trainopt $type"
            instrument = equiv[1]
        end
        scale = parse(Float64, scale)
        return Trainopt(type, instrument, filter, scale)
    end
end

"""
Assumes "WAVESHIFT INSTRUMENT FILTER SCALE MAGSHIFT INSTRUMENT FILTER SCALE" has been split into ["WAVESHIFT", "INSTRUMENT", "FILTER", "SCALE", "MAGSHIFT", "INSTRUMENT", "FILTER", "SCALE"]
"""
function parse_trainopts(trainopts_str::Vector{String}, wave_equiv::Vector{String}=Vector{String}(), mag_equiv::Vector{String}=Vector{String}())
    trainopts = Vector{Trainopt}()
    start_inds = collect(1:4:length(trainopts_str))
    for i in start_inds
        trainopt_str = join(trainopts_str[i:i+3], " ")
        trainopt = Trainopt(trainopt_str, wave_equiv, mag_equiv)
        push!(trainopts, trainopt)
    end
    return trainopts
end

end
