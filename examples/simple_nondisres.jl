using Pkg
# Activate the test-environment, where PrettyTables and HiGHS are added as dependencies.
Pkg.activate(joinpath(@__DIR__, "../test"))
# Install the dependencies.
Pkg.instantiate()
# Add the current package to the environment.
Pkg.develop(path = joinpath(@__DIR__, ".."))

using EnergyModelsBase
using EnergyModelsRenewableProducers
using HiGHS
using JuMP
using PrettyTables
using TimeStruct

const EMB = EnergyModelsBase

function demo_data()
    NG = ResourceEmit("NG", 0.2)
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    products = [NG, Power, CO2]

    # Create dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k => 0 for k ∈ products)

    # Create dictionary with entries of 0. for all emission resources
    𝒫ᵉᵐ₀ = Dict(k => 0.0 for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0

    # Create source and sink module as well as the arrays used for nodes and links
    source = RefSource(
        2,
        FixedProfile(1),
        FixedProfile(30),
        FixedProfile(10),
        Dict(NG => 1),
        [],
        𝒫ᵉᵐ₀,
    )
    sink = RefSink(
        3,
        FixedProfile(20),
        Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)),
        Dict(Power => 1),
        𝒫ᵉᵐ₀,
    )
    nodes = [GenAvailability(1, 𝒫₀, 𝒫₀), source, sink]
    links = [
        Direct(21, nodes[2], nodes[1], Linear())
        Direct(13, nodes[1], nodes[3], Linear())
    ]

    # Create time structure and the used global data
    T = TwoLevel(4, 1, SimpleTimes(24, 1))

    # Create the case dictionary
    case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

    wind = NonDisRES(
        "wind",
        FixedProfile(2),
        FixedProfile(0.9),
        FixedProfile(10),
        FixedProfile(10),
        Dict(Power => 1),
        [],
    )

    # Update nodes and links
    push!(case[:nodes], wind)
    link = EMB.Direct(41, case[:nodes][4], case[:nodes][1], EMB.Linear())
    push!(case[:links], link)

    # model = EMB.OperationalModel()
    model = EMB.OperationalModel(
        Dict(CO2 => StrategicProfile([450, 400, 350, 300]), NG => FixedProfile(1e6)),
        CO2,
    )

    return case, model
end

case, model = demo_data()

# Define an optimizer.
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = EMB.run_model(case, model, optimizer)

# Display some results
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:curtailment];
        header = [:Node, :TimePeriod, :Curtailment],
    ),
)
