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

# Copy the NEWS.md file
news = "docs/src/manual/NEWS.md"
cp("NEWS.md", news; force=true)

makedocs(
    modules = [EnergyModelsRenewableProducers],
    sitename = "EnergyModelsRenewableProducers",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
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
            "Release notes" => "manual/NEWS.md",
        ],
        "How to" => Any[
            "Update models" => "how-to/update-models.md",
            "Contribute to EnergyModelsRenewableProducers" => "how-to/contribute.md",
        ],
        "Library" =>
            Any["Public"=>"library/public.md", "Internals"=>"library/internals.md"],
    ],
)

deploydocs(;
    repo = "github.com/EnergyModelsX/EnergyModelsRenewableProducers.jl.git",
)
