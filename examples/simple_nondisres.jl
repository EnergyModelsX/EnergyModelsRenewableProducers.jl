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
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    products = [Power, CO2]

    # Create source and sink module as well as the arrays used for nodes and links
    source = RefSource(
        "source",
        FixedProfile(1),
        FixedProfile(30),
        FixedProfile(10),
        Dict(Power => 1),
        [],
    )
    sink = RefSink(
        "sink",
        FixedProfile(20),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        Dict(Power => 1),
        [],
    )
    nodes = [GenAvailability(1, products), source, sink]
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
    link = Direct(41, case[:nodes][4], case[:nodes][1], Linear())
    push!(case[:links], link)

    model = OperationalModel(
        Dict(CO2 => StrategicProfile([450, 400, 350, 300])),
        Dict(CO2 => FixedProfile(0)),
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
