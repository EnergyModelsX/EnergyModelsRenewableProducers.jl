using Documenter

using EnergyModelsBase
using EnergyModelsRenewableProducers

const EMB = EnergyModelsBase

DocMeta.setdocmeta!(
    EnergyModelsRenewableProducers,
    :DocTestSetup,
    :(using EnergyModelsRenewableProducers);
    recursive = true,
)

makedocs(
    modules = [EnergyModelsRenewableProducers],
    sitename = "EnergyModelsRenewableProducers.jl",
    repo = "https://gitlab.sintef.no/clean_export/energymodelsrenewableproducers.jl/blob/{commit}{path}#{line}",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://clean_export.pages.sintef.no/energymodelsrenewableproducers.jl/",
        edit_link = "main",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start"=>"manual/quick-start.md",
            "Optimization variables"=>"manual/optimization-variables.md",
            "Constraint functions"=>"manual/constraint-functions.md",
            "Examples"=>"manual/simple-example.md",
        ],
        "Library" =>
            Any["Public"=>"library/public.md", "Internals"=>"library/internals.md"],
    ],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
