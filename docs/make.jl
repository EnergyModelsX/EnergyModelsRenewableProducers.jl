using Documenter
using DocumenterInterLinks

using TimeStruct
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

links = InterLinks(
    "TimeStruct" => "https://sintefore.github.io/TimeStruct.jl/stable/",
    "EnergyModelsBase" => "https://energymodelsx.github.io/EnergyModelsBase.jl/stable/",
)

makedocs(
    sitename = "EnergyModelsRenewableProducers",
    modules = [EnergyModelsRenewableProducers],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = "main",
        assets = String[],
        ansicolor = true,
    ),
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Examples" => "manual/simple-example.md",
            "Release notes" => "manual/NEWS.md",
        ],
        "Nodes" => Any[
            "Non-dispatchable RES" => "nodes/nondisres.md",
            "Simple Hydropower" => "nodes/hydropower.md",
            "Detailed hydropower" => String[
                "nodes/det_hydropower/description.md",
                "nodes/det_hydropower/reservoir.md",
                "nodes/det_hydropower/generator.md",
                "nodes/det_hydropower/pump.md",
                "nodes/det_hydropower/gate.md",
            ],
            "Battery" => "nodes/battery.md",
        ],
        "How to" => Any[
            "Update models" => "how-to/update-models.md",
            "Contribute to EnergyModelsRenewableProducers" => "how-to/contribute.md",
        ],
        "Library" => Any[
            "Public" => "library/public.md",
            "Internals" => String[
                "library/internals/types-EMRP.md",
                "library/internals/methods-fields.md",
                "library/internals/methods-EMRP.md",
                "library/internals/methods-EMB.md",
            ],
        ],
    ],
    plugins=[links],
)

deploydocs(;
    repo = "github.com/EnergyModelsX/EnergyModelsRenewableProducers.jl.git",
)
