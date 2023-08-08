using Documenter
push!(LOAD_PATH, "../src/")
using SALTJacobian 

DocMeta.setdocmeta!(SALTJacobian, :DocTestSetup, :(using SALTJacobian); recursive=true)

makedocs(
    sitename="SALTJacobian Documentation",
    modules = [SALTJacobian],
    pages = [
        "SALTJacobian" => "index.md",
        "API" => "api.md"
    ],
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
    )
)

deploydocs(
    repo = "github.com/OmegaLambda1998/SALTJacobian.jl.git"
)
