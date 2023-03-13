module BatchRunModule

# External Packages

# Internal Packages
include("ToolModule.jl")
using .ToolModule
include("SurfaceModule.jl")
using .SurfaceModule

# Exports
export batch_run_SALTJacobian

function batch_run_SALTJacobian(toml::Dict)
    config = toml["GLOBAL"]

    # Load Jacobian
    if "JACOBIAN" in keys(toml)
        jacobian = jacobian_stage(toml["JACOBIAN"], config)
    else
        error("--batch mode requires a jacobian matrix, defined via --jacobian / -j path/to/jacobian_matrix")
    end

    # Create approximate surfaces
    if "SURFACE" in keys(toml)
        surfaces = surfaces_stage(toml["SURFACE"], config, jacobian)
    else
        error("--batch mode can only be used to create approximate SALT surfaces, and you must specify --base_surface / -b and --trainopt / -t")
    end
    num_trainopts = length(surfaces)
end

end

import .BatchRunModule.batch_run_SALTJacobian
