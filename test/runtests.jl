using EnergyModelsBase
using EnergyModelsRenewableProducers
using HiGHS
using JuMP
using Test
using TimeStructures

const EMB = EnergyModelsBase
const RP = EnergyModelsRenewableProducers

CO2 = ResourceEmit("CO2", 1.)
Power = ResourceCarrier("Power", 0.)

ROUND_DIGITS = 8
OPTIMIZER = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent()=>true)

function small_graph(source=nothing, sink=nothing)

    products = [Power, CO2]

    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k => 0 for k ∈ products)

    # Creation of the source and sink module as well as the arrays used for nodes and links
    if isnothing(source)
        source = RefSource(2, FixedProfile(1), FixedProfile(30), FixedProfile(10),
            Dict(Power => 1), [])
    end
    if isnothing(sink)
        sink = RefSink(3, FixedProfile(20),
            Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)),
            Dict(Power => 1))
    end

    nodes = [
        GenAvailability(1, 𝒫₀, 𝒫₀), source, sink
    ]
    links = [
        Direct(21, nodes[2], nodes[1], Linear())
        Direct(13, nodes[1], nodes[3], Linear())
    ]

    # Creation of the time structure and the used global data
    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))
    modeltype = OperationalModel(Dict(CO2 => StrategicFixedProfile([450, 400, 350, 300])),
                                CO2,
    )

    # Creation of the case dictionary
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
    )
    return case, modeltype
end


function general_tests(m)
    # Check if the solution is optimal.
    @testset "optimal solution" begin
        @test termination_status(m) == MOI.OPTIMAL

        if termination_status(m) != MOI.OPTIMAL
            @show termination_status(m)
        end
    end
end


@testset "RenewableProducers" begin
    include("test_nondisres.jl")
    include("test_hydro.jl")
    include("test_examples.jl")
end
