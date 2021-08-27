using EnergyModelsBase
using Test
using TimeStructures
using JuMP
using GLPK
using RenewableProducers

const EMB = EnergyModelsBase
const RP = RenewableProducers


NG = ResourceEmit("NG", 0.2)
CO2 = ResourceEmit("CO2", 1.)
Power = ResourceCarrier("Power", 0.)
# Coal     = ResourceCarrier("Coal", 0.35)

ROUND_DIGITS = 8


function small_graph(source=nothing, sink=nothing)
    # products = [NG, Coal, Power, CO2]
    products = [NG, Power, CO2]
    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k  => 0 for k ∈ products)
    # Creation of a dictionary with entries of 0. for all emission resources
    𝒫ᵉᵐ₀ = Dict(k  => 0. for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0

    if isnothing(source)
        source = EMB.RefSource(2, FixedProfile(1), FixedProfile(30), FixedProfile(10), Dict(NG => 1), 𝒫ᵉᵐ₀, Dict(""=>EMB.EmptyData()))
    end
    if isnothing(sink)
        sink = EMB.RefSink(3, FixedProfile(20), Dict(:surplus => 0, :deficit => 1e6), Dict(Power => 1), 𝒫ᵉᵐ₀)
    end

    nodes = [
            EMB.GenAvailability(1, 𝒫₀, 𝒫₀), source, sink
            ]
    links = [
            EMB.Direct(21, nodes[2], nodes[1], EMB.Linear())
            EMB.Direct(13, nodes[1], nodes[3], EMB.Linear())
            ]

    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))

    data = Dict(
                :nodes => nodes,
                :links => links,
                :products => products,
                :T => T,
                )
    return data
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


function general_node_tests(m, data, n::RP.RegHydroStor)
    𝒯 = data[:T]
    p_stor = [k for (k, v) ∈ n.output][1]

    @testset "stor_level bounds" begin
        # The storage level has to be greater than the required minimum.
        @test sum(n.min_level[t] * value.(m[:stor_max][n, t]) 
                <= round(value.(m[:stor_level][n, t]), digits=ROUND_DIGITS) for t in 𝒯) == length(data[:T])
        
        # The stor_level has to be less than stor_max in all operational periods.
        @test sum(value.(m[:stor_level][n, t]) <= value.(m[:stor_max][n, t]) for t in 𝒯) == length(data[:T])
        # TODO valing Storage node har negativ stor_max et par steder.
        # TODO this is ok when inflow=1. When inflow=10 the stor_level gets too large. Why?
        #  - Do we need some other sink in the system? Not logical to be left with too much power.

        # At the first operation period of each investment period, the stor_level is set as 
        # the initial reservoir level minus the production in that period.
        @test sum(value.(m[:stor_level][n, first_operational(t_inv)]) 
                    ≈ n.init_reservoir[t_inv] + n.inflow[first_operational(t_inv)]
                     + value.(m[:flow_in][n, first_operational(t_inv), p_stor])
                     - value.(m[:cap_usage][n, first_operational(t_inv)])
                for t_inv ∈ strategic_periods(𝒯)) == length(strategic_periods(𝒯))
        
        # Check that stor_level is correct wrt. previous stor_level, inflow and cap_usage.
        @test sum(value.(m[:stor_level][n, t]) ≈ value.(m[:stor_level][n, previous(t)]) 
                    + n.inflow[t] + n.input[p_stor] * value.(m[:flow_in][n, t, p_stor])
                    - value.(m[:cap_usage][n, t]) 
                for t ∈ 𝒯 if t.op > 1) == length(𝒯) - 𝒯.len
        # TODO plus flow_in
    end

    @testset "stor_max bounds" begin
        # Assure that the stor_max variable is non-negative.
        @test sum(value.(m[:stor_max][n, t]) >= 0 for t ∈ 𝒯) == length(𝒯)
       
        # Check that stor_max is set to n.cap_stor.
        @test sum(value.(m[:stor_max][n, t]) == n.cap_stor[t] for t ∈ 𝒯) == length(𝒯)
    end

    @testset "cap_usage bounds" begin
        # Cannot produce more than what is stored in the reservoir.
        @test sum(value.(m[:cap_usage][n, t]) <= value.(m[:stor_level][n, t]) 
                for t ∈ 𝒯) == length(𝒯)

        # Check that cap_usage is bounded above by cap_max.
        @test sum(round(value.(m[:cap_usage][n, t]), digits=ROUND_DIGITS) <= value.(m[:cap_max][n, t])
                for t ∈ 𝒯) == length(𝒯)
    end

    @testset "cap_max" begin
        @test sum(value.(m[:cap_max][n, t]) == n.capacity[t] for t ∈ 𝒯) == length(𝒯)
    end
    
    @testset "flow variables" begin
        # The flow_out corresponds to the production cap_usage.
        @test sum(value.(m[:flow_out][n, t, p_stor]) == value.(m[:cap_usage][n, t]) * n.output[Power] 
                for t ∈ data[:T]) == length(𝒯)

    end
end


@testset "RenewableProducers" begin

    @testset "NonDisRES" begin
        data = small_graph()
        
        wind = RP.NonDisRES("wind", FixedProfile(2), FixedProfile(0.9), 
            FixedProfile(10), FixedProfile(10), Dict(Power=>1), Dict(CO2=>0.1, NG=>0), Dict(""=>EMB.EmptyData()))

        push!(data[:nodes], wind)
        link = EMB.Direct(41, data[:nodes][4], data[:nodes][1], EMB.Linear())
        push!(data[:links], link)
        m, data = RP.run_model("", GLPK.Optimizer, data)

        𝒯 = data[:T]

        general_tests(m)

        @testset "cap_max" begin
            @test sum(value.(m[:cap_max][wind, t]) == wind.capacity[wind] for t ∈ 𝒯) == length(𝒯)
        end
        
        @testset "cap_usage bounds" begin
            # Test that cap_usage is bounded by cap_max.
            @test sum(value.(m[:cap_usage][wind, t]) <= value.(m[:cap_max][wind, t]) for t ∈ 𝒯) == length(𝒯)
                
            # Test that cap_usage is set correctly with respect to the profile.
            @test sum(value.(m[:cap_usage][wind, t]) == wind.profile[t] * value.(m[:cap_max][wind, t])
                    for t ∈ 𝒯) == length(𝒯)
        end
    end

    @testset "RegHydroStor without pump" begin
        # Setup a model with a RegHydroStor without a pump.
        data = small_graph()
        
        max_storage = FixedProfile(100)
        initial_reservoir = StrategicFixedProfile([20, 25, 30, 20])
        min_level = StrategicFixedProfile([0.1, 0.2, 0.05, 0.1])
        
        hydro = RP.RegHydroStor("-hydro", FixedProfile(2.), 
            false, initial_reservoir, max_storage, FixedProfile(1), min_level, 
            FixedProfile(10), FixedProfile(10), Dict(Power=>0.9), Dict(Power=>1), 
            Dict(CO2=>0.01, NG=>0), Dict(""=>EMB.EmptyData()))
        
        push!(data[:nodes], hydro)
        link_from = EMB.Direct(41, data[:nodes][4], data[:nodes][1], EMB.Linear())
        push!(data[:links], link_from)
        link_to = EMB.Direct(14, data[:nodes][1], data[:nodes][4], EMB.Linear())
        push!(data[:links], link_to)

        m, data = RP.run_model("", GLPK.Optimizer, data)

        𝒯 = data[:T]

        general_tests(m)

        general_node_tests(m, data, hydro)

        @testset "no pump" begin
            # No pump means no inflow.
            @test sum(value.(m[:flow_in][hydro, t, p]) == 0 for t ∈ 𝒯 for p ∈ keys(hydro.input)) == length(𝒯)
        end
        
        @testset "flow_in" begin
            # Check that the zero equality constraint is set on the flow_in variable 
            # when the pump is not allowed. If this fais, there might be errors in 
            # the links to the node. The hydro node need one in and one out.
            @test sum(occursin("flow_in[n-hydro,t1_1,Power] == 0.0", string(constraint))
                for constraint ∈ all_constraints(m, AffExpr, MOI.EqualTo{Float64})) == 1
        end
            
    end # testset RegHydroStor without pump


    @testset "RegHydroStor with pump" begin
        # Setup a model with a RegHydroStor without a pump.
        
        products = [NG, Power, CO2]
        𝒫ᵉᵐ₀ = Dict(k  => 0. for k ∈ products if typeof(k) == ResourceEmit{Float64})
        source = EMB.RefSource("-source", DynamicProfile([10 10 10 10 10 0 0 0 0 0;
                                                          10 10 10 10 10 0 0 0 0 0;]),
                                FixedProfile(10), FixedProfile(10), Dict(Power => 1), 𝒫ᵉᵐ₀, Dict(""=>EMB.EmptyData()))
        sink = EMB.RefSink("-sink", FixedProfile(7), Dict(:surplus => 0, :deficit => 1e6), Dict(Power => 1), 𝒫ᵉᵐ₀)
        
        data = small_graph(source, sink)
        
        max_storage = FixedProfile(100)
        initial_reservoir = StrategicFixedProfile([20, 25])
        min_level = StrategicFixedProfile([0.1, 0.2])
        
        hydro = RP.RegHydroStor("-hydro", FixedProfile(10.), 
            true, initial_reservoir, max_storage, FixedProfile(1), min_level, 
            FixedProfile(30), FixedProfile(10), Dict(Power=>1), Dict(Power=>0.9), 
            Dict(CO2=>0.01, NG=>0), Dict(""=>EMB.EmptyData()))
        
        push!(data[:nodes], hydro)
        link_from = EMB.Direct(41, data[:nodes][4], data[:nodes][1], EMB.Linear())
        push!(data[:links], link_from)
        link_to = EMB.Direct(14, data[:nodes][1], data[:nodes][4], EMB.Linear())
        push!(data[:links], link_to)

        data[:T] = UniformTwoLevel(1, 2, 1, UniformTimes(1, 10, 1))
        m, data = RP.run_model("", GLPK.Optimizer, data)
        𝒯 = data[:T]

        general_tests(m)

        general_node_tests(m, data, hydro)

        @testset "flow_in" begin
            # Check that the zero equality constraint is not set on the flow_in variable 
            # when the pump is allowed. If this fails, there might be errors in the links
            # to the node. The hydro node need one in and one out.
            @test sum(occursin("flow_in[n-hydro,t1_1,Power] == 0.0", string(constraint))
                for constraint ∈ all_constraints(m, AffExpr, MOI.EqualTo{Float64})) == 0
        end

        @testset "deficit" begin
            if sum(value.(m[:deficit][sink, t]) for t ∈ 𝒯) > 0
                # Check that the other source operates on its maximum if there is a deficit at the sink node,
                # since this should be used to fill the reservoir (if the reservoir is not full enough at the
                # beginning, and the inflow is too low).
                @assert sum(value.(m[:cap_usage][source, t]) == value.(m[:cap_max][source, t]) for t ∈ 𝒯) == length(𝒯)
            end
        end

    end # testset RegHydroStor with pump
end
