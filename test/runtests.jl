using EnergyModelsBase
using Test
using TimeStructures
using JuMP
using GLPK

const EMB = EnergyModelsBase
const RP = RenewableProducers


CO2 = ResourceEmit("CO2", 1.)
Power = ResourceCarrier("Power", 1.)

# a = NonDispatchableRenewableEnergy("wind", FixedProfile(2), FixedProfile(1000), FixedProfile(10), Dict(Power=>1), Dict(CO2=>0.1))


function small_graph()
    NG       = ResourceEmit("NG", 0.2)
    Coal     = ResourceCarrier("Coal", 0.35)
    Power    = ResourceCarrier("Power", 0.)
    CO2      = ResourceEmit("CO2",1.)
    # products = [NG, Coal, Power, CO2]
    products = [Power, CO2]
    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k  => 0 for k ∈ products)
    # Creation of a dictionary with entries of 0. for all emission resources
    𝒫ᵉᵐ₀ = Dict(k  => 0. for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0
    nodes = [
            EMB.Availability(1, 𝒫₀, 𝒫₀),
            EMB.RefSource(2, FixedProfile(1), FixedProfile(30), Dict(Power => 1), 𝒫ᵉᵐ₀),
            EMB.RefSink(3, FixedProfile(20), Dict(:surplus => 0, :deficit => 1e6), Dict(Power => 1), 𝒫ᵉᵐ₀),
            ]
    links = [
            EMB.Direct(21,nodes[2],nodes[1],EMB.Linear())
            EMB.Direct(13,nodes[1], nodes[3], EMB.Linear())
            ]

    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))
    # WIP data structure
    data = Dict(
                :nodes => nodes,
                :links => links,
                :products => products,
                :T => T,
                )
    return data
end


@testset "RegulatedHydroStorage without pump" begin
    # Setup a model with a RegulatedHydroStorage without a pump.
    data = small_graph()
    
    max_storage = 100
    min_level = 0.1
    
    hydro = RegulatedHydroStorage(9, FixedProfile(2.), 
    false, 20, max_storage, FixedProfile(1), min_level, 
    FixedProfile(10), Dict(Power=>0.9), Dict(Power=>1), 
    Dict(CO2=>0.01, NG=>0))
    
    push!(data[:nodes], hydro)
    link = EMB.Direct(41, data[:nodes][4], data[:nodes][1], EMB.Linear())
    push!(data[:links], link)
    
    m, data = RP.run_model("", GLPK.Optimizer, data)
    display(solution_summary(m))

    𝒯 = data[:T]

    @testset "optimal solution" begin
        @test termination_status(m) == MOI.OPTIMAL
    end

    @testset "stor_level bounds" begin
        # The storage level has to be greater than the required minimum.
        @test sum(hydro.min_level * hydro.cap_reservoir <= value.(m[:stor_level][hydro, t]) for t in 𝒯) == length(data[:T])
        
        # The stor_level has to be less than stor_max in all operational periods.
        @test sum(value.(m[:stor_level][hydro, t]) <= value.(m[:stor_max][hydro, t]) for t in 𝒯) == length(data[:T])
        # TODO valing Storage node har negativ stor_max et par steder.
        # TODO this is ok when inflow=1. When inflow=10 the stor_level gets too large. Why?
        #  - Do we need some other sink in the system? Not logical to be left with too much power.

        # At the first operation period of each investment period, the stor_level is set as 
        # the initial reservoir level minus the production in that period.
        @test sum(value.(m[:stor_level][hydro, first_operational(t_inv)]) 
                    == hydro.init_reservoir - value.(m[:cap_usage][hydro, first_operational(t_inv)])
                for t_inv ∈ strategic_periods(𝒯)) == length(strategic_periods(𝒯))
        
        # Check that stor_level is correct wrt. previous stor_level, inflow and cap_usage.
        @test sum(value.(m[:stor_level][hydro, t]) == value.(m[:stor_level][hydro, previous(t)]) 
                    + hydro.inflow[t] - value.(m[:cap_usage][hydro, t]) 
                for t ∈ 𝒯 if t.op > 1) == length(𝒯) - 𝒯.len
    end

    @testset "cap_usage bounds" begin
        # Cannot produce more than what is stored in the reservoir.
        @test sum(value.(m[:cap_usage][hydro, t]) <= value.(m[:stor_level][hydro, t]) 
                for t ∈ 𝒯) == length(𝒯)

        @test sum(value.(m[:cap_usage][hydro, t]) <= value.(m[:cap_max][hydro, t])
                for t ∈ 𝒯) == length(𝒯)
    end

    @testset "flow variables" begin
        # No pump means no inflow.
        @test sum(value.(m[:flow_in][hydro, t, p]) == 0 for t ∈ 𝒯 for p ∈ keys(hydro.input)) == length(𝒯)
        
        # The flow_out corresponds to the production cap_usage.
        @test sum(value.(m[:flow_out][hydro, t, Power]) == value.(m[:cap_usage][hydro, t]) * hydro.output[Power] 
                for t ∈ data[:T]) == length(𝒯)
    end

end