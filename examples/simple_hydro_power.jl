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

function generate_data()
    @info "Generate data"

    # Build on the example used in energymodelsbase.jl
    # case, modeltype = EMB.read_data(fn)

    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 1.0)

    products = [CO2, Power]

    av = GenAvailability(1, products)

    # Add a non-dispatchable renewable energy source to the system
    rs = NonDisRES(
        "wind",
        FixedProfile(2.0),
        FixedProfile(0.8),
        FixedProfile(5),
        FixedProfile(10),
        Dict(Power => 1.0),
        [],
    )

    hydro = HydroStor(
        "hydropower",
        FixedProfile(2.0),
        FixedProfile(90),
        FixedProfile(10),
        FixedProfile(1),
        FixedProfile(0.0),
        FixedProfile(0),
        FixedProfile(3),
        Power,
        Dict(Power => 0.9),
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

    nodes = [av, rs, hydro, sink]
    links = [
        Direct("rs-av", rs, av),
        Direct("hy-av", hydro, av),
        Direct("av-hy", av, hydro),
        Direct("av-si", av, sink),
    ]

    # Create time structure and the used global data
    T = TwoLevel(4, 1, SimpleTimes(24, 1))

    case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

    modeltype = OperationalModel(
        Dict(CO2 => StrategicProfile([450, 400, 350, 300])),
        Dict(CO2 => FixedProfile(0)),
        CO2,
    )
    return case, modeltype
end

case, modeltype = generate_data()

m = EMB.run_model(case, modeltype, HiGHS.Optimizer)

function inspect_results()
    power = case[:products][2]
    sink = case[:nodes][4]
    T = case[:T]

    @show power
    for t ∈ T
        @show t value.(m[:flow_in][sink, t, power])
    end
end

# Uncomment to show some of the results.
# inspect_results()
