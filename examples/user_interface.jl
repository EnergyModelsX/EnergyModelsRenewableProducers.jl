using Pkg
Pkg.activate(joinpath(@__DIR__, "../test"))
Pkg.instantiate()
Pkg.develop(path=joinpath(@__DIR__, ".."))

using EnergyModelsBase
using EnergyModelsRenewableProducers
using HiGHS
using JuMP
using PrettyTables
using TimeStructures

const EMB = EnergyModelsBase
const RP = EnergyModelsRenewableProducers

function generate_data()
    @info "Generate data"

    # Build on the example used in energymodelsbase.jl
    # case, modeltype = EMB.read_data(fn)

    CO2         = ResourceEmit("CO2", 1.)
    NG          = ResourceEmit("NG", 0.2)
    Power       = ResourceCarrier("Power", 1.)

    products = [CO2, NG, Power]
    emissions   = Dict(CO2=>0.01, NG=>0)
    𝒫₀ = Dict(p => 0 for p ∈ products)
    
    av = GenAvailability(1, 𝒫₀, 𝒫₀)
    
    # Add a non-dispatchable renewable energy source to the system
    rs = NonDisRES(2, FixedProfile(2.), FixedProfile(0.8), FixedProfile(5),
                   FixedProfile(10), Dict(Power=>1.), Dict())

    hydro = RegHydroStor(3, FixedProfile(2.),  FixedProfile(90), 
                         false, FixedProfile(10),
                         FixedProfile(1), FixedProfile(0.0), FixedProfile(4),
                         FixedProfile(3), Power, Dict(Power=>0.9), Dict(Power=>1), 
                         Dict())

    sink = RefSink(
        4,
        FixedProfile(20),
        Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)),
        Dict(Power => 1),
        emissions,
    )

    nodes = [av, rs, hydro, sink]
    links = [
        Direct("rs-av", rs, av),
        Direct("hy-av", hydro, av),
        Direct("av-hy", av, hydro),
        Direct("av-si", av, sink)
    ]

    # Create time structure and the used global data
    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))
    
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
    )

    modeltype = EMB.OperationalModel(
        Dict(CO2 => StrategicFixedProfile([450, 400, 350, 300]), NG => FixedProfile(1e6)),
        CO2
    )
    return case, modeltype
end


case, modeltype = generate_data()

m = EMB.run_model(case, modeltype, HiGHS.Optimizer)


function inspect_results()
    power = case[:products][3]
    sink = case[:nodes][4]
    T = case[:T]

    @show power
    for t ∈ T
        @show t value.(m[:flow_in][sink, t, power])
    end
end

# Uncomment to show some of the results.
# inspect_results()
