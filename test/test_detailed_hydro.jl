## START - ONLY FOR TESTING ##
using Revise
using Pkg
# Activate the local environment including EnergyModelsRenewableProducers, HiGHS, PrettyTables
Pkg.activate(@__DIR__)
# Use dev version if run as part of tests
Pkg.resolve()
Pkg.develop(path=joinpath(@__DIR__, ".."))
#Pkg.activate()
# Install the dependencies.
Pkg.instantiate()
## END - ONLY FOR TESTING ##


using EnergyModelsBase
using EnergyModelsRenewableProducers
using HiGHS
using JuMP
using Test
using TimeStruct

const EMB = EnergyModelsBase
const EMRP = EnergyModelsRenewableProducers

function build_case()
    # Define the different resources and their emission intensity in tCO2/MWh
    # CO2 has to be defined, even if not used, as it is required for the `EnergyModel` type
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    Water = ResourceCarrier("Water", 0.0)
    products = [CO2, Power, Water]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Operationl period duration
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = op_duration * op_number

    # Create the time structure and global data
    T = TwoLevel(2, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO2 in t/8h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO2 in EUR/t
        CO2,                            # CO2 instance
    )

    # Create a hydro reservoir
    hydro_reservoir = HydroReservoir{CyclicStrategic}(
        "hydro_reservoir",  # Node ID
        StorCap(
            FixedProfile(100), # vol, maximum capacity in mm3
        ),
        OperationalProfile([5, 10, 15, 20]),   # storage_inflow
        Water,              # stor_res, stored resource
        Dict(Water => 1),               # input
        Dict(Water => 1),               # output

    )

    # Create a hydro reservoir gate
    hydro_gate = HydroGate(
        "hydro_gate",  # Node ID
        FixedProfile(1000),     # cap, in mm3/timestep
        FixedProfile(0),      # opex_var, variable OPEX in EUR/(mm3/h?)
        FixedProfile(0),        # opex_fixed, Fixed OPEX in EUR/(mm3/h?)
        Dict(Water => 1),       # input
        Dict(Water => 1),       # output
    )

    # Create a hydro sink
    hydro_ocean = RefSink(
        "ocean",   # Node id
        FixedProfile(0),    # No demand for water
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(0)),
        Dict(Water => 1),   # Resource and corresponding ratio
    )

    # Create the array of ndoes
    nodes = [hydro_reservoir, hydro_gate, hydro_ocean]
    links = [
        Direct("hydro_res-hydro_gate", hydro_reservoir, hydro_gate),
        Direct("hydro_gate-ocean", hydro_gate, hydro_ocean)
    ]

    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T
    )
    return case, model
end

@testset "Test hydro reservoir level_Δ == inflow - discharge" begin
    case, model = build_case()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    m = EMB.run_model(case, model, optimizer)

    𝒯 = case[:T]
    hydro_reservoir = case[:nodes][1]
    hydro_gate = case[:nodes][2]
    Water = case[:products][3]

    level_Δ = value.([m[:stor_level_Δ_op][hydro_reservoir, t] for t in 𝒯])
    discharge = value.([m[:flow_in][hydro_gate, t, Water] for t in 𝒯])
    inflow = [hydro_reservoir.vol_inflow[t] for t in 𝒯]
    @test level_Δ == inflow - discharge
end

@testset "Test hydro reservoir hard MinConstraint and MaxConstraint" begin
    case, model = build_case()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    𝒯 = case[:T]
    hydro_reservoir = case[:nodes][1]
    hydro_gate = case[:nodes][2]
    Water = case[:products][3]
    max_profile = [1, 0.8, 0.8, 1]
    push!(hydro_reservoir.data,
        MaxConstraint(
            Symbol(),
            OperationalProfile(max_profile), # value
            FixedProfile(true),                 # flag
            FixedProfile(Inf),                  # penalty
        )
    )
    min_profile = [1, 0, 0, 0]
    push!(hydro_reservoir.data,
        MinConstraint(
            Symbol(),
            OperationalProfile(min_profile), # value
            FixedProfile(true),                 # flag
            FixedProfile(Inf),                  # penalty
        )
    )
    m = EMB.run_model(case, model, optimizer)
    for sp in TS.strategic_periods(𝒯)
        rsv_vol = value.([m[:stor_level][hydro_reservoir, t] for t in sp])
        min_vol = [hydro_reservoir.vol.capacity[t] for t in sp] .* min_profile
        max_vol = [hydro_reservoir.vol.capacity[t] for t in sp] .* max_profile
        @test min_vol ≤ rsv_vol ≤ max_vol
    end
end

@testset "Test hydro reservoir hard MaxConstraint penalty cost" begin
    case, model = build_case()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    𝒯 = case[:T]
    hydro_reservoir = case[:nodes][1]
    hydro_gate = case[:nodes][2]
    Water = case[:products][3]
    # Verify reservoir minimum/maximum hard constraint
    max_profile = [1, 0, 0.8, 1]
    penalty_cost = 57
    push!(hydro_reservoir.data,
        MaxConstraint(
            Symbol(),
            OperationalProfile(max_profile), # value
            OperationalProfile([false, true, false, false]),                 # flag
            FixedProfile(penalty_cost),                  # penalty
        )
    )
    min_profile = [1, 0, 0, 0]
    push!(hydro_reservoir.data,
        MinConstraint(
            Symbol(),
            OperationalProfile(min_profile), # value
            FixedProfile(true),                 # flag
            FixedProfile(Inf),                  # penalty
        )
    )
    m = EMB.run_model(case, model, optimizer)
    # sp = first(TS.strategic_periods(𝒯))
    max_vol_violation_cost = 0
    for sp in TS.strategic_periods(𝒯)
        rsv_vol = value.([m[:stor_level][hydro_reservoir, t] for t in sp])
        min_vol = [hydro_reservoir.vol.capacity[t] for t in sp] .* min_profile
        max_vol = [hydro_reservoir.vol.capacity[t] for t in sp] .* max_profile
        max_vol_violation = max.(rsv_vol - max_vol, 0)
        max_vol_violation_cost += sum(max_vol_violation * 57)
    end
    @test objective_value(m) + max_vol_violation_cost == 0
end
