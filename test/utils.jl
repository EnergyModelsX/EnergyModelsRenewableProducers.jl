
CO2 = ResourceEmit("CO2", 1.0)
Power = ResourceCarrier("Power", 0.0)

TEST_ATOL = 1e-6
ROUND_DIGITS = 8
OPTIMIZER = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

function small_graph(; source = nothing, sink = nothing, ops = SimpleTimes(24, 2))

    products = [Power, CO2]
    # Creation of the source and sink module as well as the arrays used for nodes and links
    if isnothing(source)
        source = RefSource(
            2,
            FixedProfile(1),
            FixedProfile(30),
            FixedProfile(10),
            Dict(Power => 1),
        )
    end
    if isnothing(sink)
        sink = RefSink(
            3,
            FixedProfile(20),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            Dict(Power => 1),
        )
    end

    nodes = [GenAvailability(1, products), source, sink]
    links = [
        Direct(21, nodes[2], nodes[1], Linear())
        Direct(13, nodes[1], nodes[3], Linear())
    ]

    # Creation of the time structure and the used global data
    T = TwoLevel(4, 1, ops)
    modeltype = OperationalModel(
        Dict(CO2 => StrategicProfile([450, 400, 350, 300])),
        Dict(CO2 => FixedProfile(0)),
        CO2,
    )

    # Creation of the case dictionary
    case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)
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
