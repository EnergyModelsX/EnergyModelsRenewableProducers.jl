function build_case_gate()
    # Define the different resources and their emission intensity in tCO2/MWh
    # CO2 has to be defined, even if not used, as it is required for the `EnergyModel` type
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    Water = ResourceCarrier("Water", 0.0)
    products = [CO2, Power, Water]

    # Variables for the individual entries of the time structure
    op_duration = [1, 1, 2, 4] # Operational period duration
    op_number = length(op_duration)   # Number of operational periods
    operational_periods = SimpleTimes(op_number, op_duration) # Assume step length is given i

    # The number of operational periods times the duration of the operational periods.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = sum(op_duration)

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
    )

    # Create a hydro reservoir gate
    hydro_gate = HydroGate(
        "hydro_gate",  # Node ID
        FixedProfile(100),     # cap, in mm3/timestep
        FixedProfile(0),      # opex_var, variable OPEX in EUR/(mm3/h?)
        FixedProfile(0),        # opex_fixed, Fixed OPEX in EUR/(mm3/h?)
        Water,
    )

    # Create a hydro sink
    hydro_ocean = RefSink(
        "ocean",   # Node id
        FixedProfile(15),    # Firm demand that can't be fulfilled
        Dict(
            :surplus => FixedProfile(0),
            :deficit => OperationalProfile([0, 20, 0, 0]) # Cost for violating demand at step 2
        ),
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
    case, model = build_case_gate()
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
    @test objective_value(m) == 0
end

@testset "Test hydro reservoir hard Constraint of type MinConstraintType and MaxConstraintType" begin
    case, model = build_case_gate()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    𝒯 = case[:T]
    hydro_reservoir = case[:nodes][1]
    hydro_gate = case[:nodes][2]
    hydro_ocean = case[:nodes][3]
    Water = case[:products][3]
    max_profile = [0.2, 0.8, 0.8, 1]
    push!(hydro_reservoir.data,
        Constraint{MaxConstraintType}(
            nothing,
            OperationalProfile(max_profile), # value
            FixedProfile(true),              # flag
            FixedProfile(Inf),               # penalty
        )
    )
    min_profile = [0.2, 0.2, 0, 0]
    push!(hydro_reservoir.data,
        Constraint{MinConstraintType}(
            nothing,
            OperationalProfile(min_profile), # value
            FixedProfile(true),              # flag
            FixedProfile(Inf),               # penalty
        )
    )
    m = EMB.run_model(case, model, optimizer)

    # Find the discharge deficit cost for each strategic period
    discharge_deficit_cost = map(strategic_periods(𝒯)) do sp
        rsv_vol = value.([m[:stor_level][hydro_reservoir, t] for t in sp])
        min_vol = [hydro_reservoir.vol.capacity[t] for t in sp] .* min_profile
        max_vol = [hydro_reservoir.vol.capacity[t] for t in sp] .* max_profile
        @test min_vol ≤ rsv_vol ≤ max_vol

        discharge = value.([m[:flow_in][hydro_gate, t, Water] for t in sp])
        demand = [hydro_ocean.cap[t] for t in sp]
        deficit = max.(demand - discharge, 0)
        penalty = [hydro_ocean.penalty[:deficit][t] for t in sp]
        return sum(deficit .* penalty .* [duration(t) for t in sp])
    end
    # Verify that restriction has caused a deficit meaning that optimal solution has changes
    @test sum(discharge_deficit_cost) > 0
    @test objective_value(m) + sum(discharge_deficit_cost) == 0
end

@testset "Test hydro reservoir Constraint of type MaxConstraintType with penalty cost" begin
    case, model = build_case_gate()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    𝒯 = case[:T]
    hydro_reservoir = case[:nodes][1]
    hydro_gate = case[:nodes][2]
    Water = case[:products][3]

    # Verify reservoir minimum/maximum hard constraint
    max_profile = [1, 0, 0.8, 1]
    penalty_cost = 57
    push!(hydro_reservoir.data,
        Constraint{MaxConstraintType}(
            nothing,
            OperationalProfile(max_profile), # value
            OperationalProfile([false, true, false, false]), # flag
            FixedProfile(penalty_cost),                      # penalty
        )
    )
    min_profile = [1, 0, 0, 0]
    push!(hydro_reservoir.data,
        Constraint{MinConstraintType}(
            nothing,
            OperationalProfile(min_profile), # value
            FixedProfile(true),              # flag
            FixedProfile(Inf),               # penalty
        )
    )
    m = EMB.run_model(case, model, optimizer)

    # Find the max vol violation cost for each strategic period
    max_vol_violation_cost = map(strategic_periods(𝒯)) do sp
        rsv_vol = value.([m[:stor_level][hydro_reservoir, t] for t in sp])
        min_vol = [capacity(level(hydro_reservoir), t) for t in sp] .* min_profile
        max_vol = [capacity(level(hydro_reservoir), t) for t in sp] .* max_profile
        max_vol_violation = max.(rsv_vol - max_vol, 0)
        return sum(max_vol_violation .* [duration(t) for t in sp] * penalty_cost)
    end
    @test objective_value(m) + sum(max_vol_violation_cost) == 0
end

@testset "Test hydro gate schedule" begin
    case, model = build_case_gate()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    𝒯 = case[:T]
    hydro_reservoir = case[:nodes][1]
    hydro_gate = case[:nodes][2]
    Water = case[:products][3]

    # Verify reservoir minimum/maximum hard constraint
    schedule_profile = 0.1 * ones(4)
    flags = [false, true, true, false]
    penalty_cost = 57
    push!(hydro_gate.data,
        Constraint{ScheduleConstraintType}(
            nothing,
            OperationalProfile(schedule_profile), # value
            OperationalProfile(flags),            # flag
            FixedProfile(penalty_cost),           # penalty
        )
    )
    m = EMB.run_model(case, model, optimizer)

    for sp in strategic_periods(𝒯)
        gate_flow = value.([m[:flow_out][hydro_gate, t, Water] for t in sp])
        schedule_value = schedule_profile .* [capacity(hydro_gate, t) for t in sp]
        # Verify that schedule equals flow when flag is set
        @test all(.!flags .| (schedule_value .== gate_flow))
    end
end

@testset "Test hydro gate schedule penalty value" begin
    case, model = build_case_gate()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    𝒯 = case[:T]
    hydro_reservoir = case[:nodes][1]
    hydro_gate = case[:nodes][2]
    hydro_ocean = case[:nodes][3]
    Water = case[:products][3]

    # Verify reservoir minimum/maximum hard constraint
    schedule_profile = 0.1 * ones(4)
    penalty_cost = [12, 23, 57, 44]
    push!(hydro_gate.data,
        Constraint{ScheduleConstraintType}(
            nothing,
            OperationalProfile(schedule_profile), # value
            FixedProfile(true),                   # flag
            OperationalProfile(penalty_cost),     # penalty
        )
    )
    m = EMB.run_model(case, model, optimizer)

    # for sp in strategic_periods(𝒯)
    gate_penalties = map(strategic_periods(𝒯)) do sp
        gate_flow = value.([m[:flow_out][hydro_gate, t, Water] for t in sp])
        schedule_value = schedule_profile .* [capacity(hydro_gate, t) for t in sp]
        deviation_up = max.(gate_flow - schedule_value, 0)
        deviation_down = -min.(gate_flow - schedule_value, 0)
        return sum(deviation_down .* [duration(t) for t in sp] .* penalty_cost) +
            sum(deviation_up .* [duration(t) for t in sp] .* penalty_cost)
    end

    # Hydro ocean demand
    demand_penalties = map(strategic_periods(𝒯)) do sp
        gate_flow = value.([m[:flow_out][hydro_gate, t, Water] for t in sp])
        demand = [hydro_ocean.cap[t] for t in sp]
        deficit = max.(demand - gate_flow, 0)
        penalty = [hydro_ocean.penalty[:deficit][t] for t in sp]
        return sum(deficit .* penalty .* [duration(t) for t in sp])
    end

    @test objective_value(m) + sum(gate_penalties) + sum(demand_penalties) ≈ 0
end

function build_case_generator()
    case, model = build_case_gate()
    Power = case[:products][2]
    Water = case[:products][3]
    hydro_gen_cap = 20
    hydro_generator = HydroGenerator(
        "hydro_generator", # Node ID
        FixedProfile(hydro_gen_cap),                # Installed discharge capacity
        PqPoints(
            [0, 10, 20] / hydro_gen_cap,
            [0, 10, 22] / hydro_gen_cap
        ),          # PQ-curve
        FixedProfile(0),   # opex_var
        FixedProfile(0),   # opex_fixed
        Power,
        Water
    )

    electricty_market = RefSink(
        "market",
        FixedProfile(0),
        Dict(
            :surplus => OperationalProfile(-[10, 11, 12, 13]),
            :deficit => FixedProfile(1000)
        ),
        Dict(Power => 1.0),
        Data[]
    )

    hydro_reservoir = case[:nodes][1]
    hydro_ocean = case[:nodes][3]

    push!(case[:nodes], hydro_generator)
    push!(case[:links], Direct("hydro_res-hydro_gen", hydro_reservoir, hydro_generator))
    push!(case[:links], Direct("hydro_gen-hydro_ocean", hydro_generator, hydro_ocean))

    push!(case[:nodes], electricty_market)
    push!(case[:links], Direct("hydro_gen-market", hydro_generator, electricty_market))

    return case, model
end

@testset "Test plant production income and PQ relation" begin
    case, model = build_case_generator()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    m = EMB.run_model(case, model, optimizer)

    hydro_reservoir = case[:nodes][1]
    hydro_gate = case[:nodes][2]
    hydro_ocean = case[:nodes][3]
    hydro_generator = case[:nodes][4]

    Power = case[:products][2]
    Water = case[:products][3]

    # Check that production and discharge follows PQ-curve
    # Check the total costs sums up to the objective
    # 1. Costs for violating minimum discharge
    # 2. Production costs (negative since they are income)
    total_cost = map(strategic_periods(case[:T])) do sp
        plant_discharge = value.([m[:flow_out][hydro_generator, t, Water] for t in sp])
        gate_discharge = value.([m[:flow_out][hydro_gate, t, Water] for t in sp])
        total_discharge = plant_discharge + gate_discharge
        min_discharge = [hydro_ocean.cap[t] for t in sp]
        min_discharge_penalty = [hydro_ocean.penalty[:deficit][t] for t in sp]
        min_discharge_cost = max.(min_discharge - total_discharge, 0) .* min_discharge_penalty

        production = value.([m[:flow_out][hydro_generator, t, Power] for t in sp])
        discharge = value.([m[:flow_out][hydro_generator, t, Water] for t in sp])
        discharge_estimated = map(sp) do t
            prod_to_discharge = Interpolations.linear_interpolation(
                hydro_generator.pq_curve.power_levels * capacity(hydro_generator, t),
                hydro_generator.pq_curve.discharge_levels * capacity(hydro_generator, t)
            )
            discharge_estimated = prod_to_discharge(
                value(m[:flow_out][hydro_generator, t, Power])
            )
        end

        # Check that points are on curve
        @test discharge ≈ discharge_estimated atol=1e-12

        price = [case[:nodes][5].penalty[:surplus][t] for t in sp]
        production_cost = production .* price

        total_cost = (min_discharge_cost + production_cost) .* [duration(t) for t in sp]
        return sum(total_cost)
    end
    @test objective_value(m) + sum(total_cost) ≈ 0 atol=1e-12
end

@testset "Test plant production schedule" begin
    case, model = build_case_generator()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    hydro_reservoir = case[:nodes][1]
    hydro_gate = case[:nodes][2]
    hydro_ocean = case[:nodes][3]
    hydro_generator = case[:nodes][4]
    market = case[:nodes][5]

    Power = case[:products][2]
    Water = case[:products][3]

    # Modify price to increase production in first hours to ensure schedule changes solution
    market.penalty[:surplus] = OperationalProfile(-[50, 50, 10, 10])

    # Verify power schedule
    schedule_profile = 0.8 * ones(4)
    schedule_flag = [false, false, true, true]
    push!(hydro_generator.data,
        Constraint{ScheduleConstraintType}(
            Power,
            OperationalProfile(schedule_profile),  # value
            OperationalProfile(schedule_flag),     # flag
            FixedProfile(Inf),                     # penalty
        )
    )
    m = EMB.run_model(case, model, optimizer)

    res = map(strategic_periods(case[:T])) do sp
        production = value.([m[:flow_out][hydro_generator, t, Power] for t in sp])
        discharge = value.([m[:flow_out][hydro_generator, t, Water] for t in sp])
        production_cap = [capacity(hydro_generator, t) for t in sp]
        discharge, production, production_cap
    end

    # Test that production equal capacity * schedule_profile when schedule_flag is set
    for sp in strategic_periods(case[:T])
        production = value.([m[:flow_out][hydro_generator, t, Power] for t in sp])
        discharge = value.([m[:flow_out][hydro_generator, t, Water] for t in sp])
        production_cap = [capacity(hydro_generator, t) for t in sp]
        @test all(.!schedule_flag .| (production .≈ production_cap .* schedule_profile))
    end
end

@testset "Test plant minimum discharge" begin
    case, model = build_case_generator()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    hydro_reservoir = case[:nodes][1]
    hydro_gate = case[:nodes][2]
    hydro_ocean = case[:nodes][3]
    hydro_generator = case[:nodes][4]
    market = case[:nodes][5]

    Power = case[:products][2]
    Water = case[:products][3]

    # Verify power schedule
    min_discharge_factor = 0.5
    push!(hydro_generator.data,
        Constraint{MinConstraintType}(
            Water,
            FixedProfile(min_discharge_factor), # value
            FixedProfile(true),                 # flag
            FixedProfile(50),                   # penalty
        )
    )
    m = EMB.run_model(case, model, optimizer)

    for sp in strategic_periods(case[:T])
        discharge = value.([m[:flow_out][hydro_generator, t, Water] for t in sp])
        discharge_cap = [capacity(hydro_generator, t, Water) for t in sp]
        @test discharge ≥ discharge_cap * min_discharge_factor
    end
end

function build_case_pump()
    # Define the different resources and their emission intensity in tCO2/MWh
    # CO2 has to be defined, even if not used, as it is required for the `EnergyModel` type
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    Water = ResourceCarrier("Water", 0.0)
    products = [CO2, Power, Water]

    # Variables for the individual entries of the time structure
    op_duration = [1, 1, 2, 4] # Operational period duration
    op_number = length(op_duration)   # Number of operational periods
    operational_periods = SimpleTimes(op_number, op_duration) # Assume step length is given i

    # The number of operational periods times the duration of the operational periods.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = sum(op_duration)

    # Create the time structure and global data
    T = TwoLevel(2, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO2 in t/8h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO2 in EUR/t
        CO2,                            # CO2 instance
    )

    # Create a hydro reservoir
    reservoir_up = HydroReservoir{CyclicStrategic}(
        "hydro_reservoir_up",  # Node ID
        StorCap(
            FixedProfile(100), # vol, maximum capacity in mm3
        ),
        OperationalProfile([0, 0, 0, 0]),   # storage_inflow
        Water,              # stor_res, stored resource
    )

    reservoir_down = HydroReservoir{CyclicStrategic}(
        "hydro_reservoir_down",  # Node ID
        StorCap(
            FixedProfile(100), # vol, maximum capacity in mm3
        ),
        OperationalProfile([0, 0, 0, 0]),   # storage_inflow
        Water,              # stor_res, stored resource
    )

    hydro_gen_cap = 20
    hydro_generator = HydroGenerator(
        "hydro_generator",
        FixedProfile(hydro_gen_cap),                # Installed discharge capacity
        PqPoints(
            [0, 10, 20] / hydro_gen_cap,
            [0, 10, 22] / hydro_gen_cap
        ),          # PQ-curve
        FixedProfile(0),   # opex_var
        FixedProfile(0),   # opex_fixed
        Power,
        Water
    )

    hydro_pump_cap = 30
    hydro_pump = HydroPump(
        "hydro_pump",
        FixedProfile(hydro_pump_cap),                # Installed discharge capacity
        PqPoints(
            [0, 15, 30] / hydro_pump_cap,
            [0, 12, 20] / hydro_pump_cap
        ),          # PQ-curve
        FixedProfile(0),   # opex_var
        FixedProfile(0),   # opex_fixed
        Power,
        Water
    )

    market_sale = RefSink(
        "market",
        FixedProfile(0),
        Dict(
            :surplus => OperationalProfile(-[10, 60, 15, 65]),
            :deficit => FixedProfile(1000)
        ),
        Dict(Power => 1.0),
        Data[]
    )

    market_buy = RefSource(
        "market_buy",
        FixedProfile(1000),
        OperationalProfile([10, 60, 15, 65]),
        FixedProfile(0),
        Dict(Power => 1.0),
        Data[]
    )

    # Create the array of ndoes
    nodes = [reservoir_up, reservoir_down, hydro_generator, hydro_pump, market_sale, market_buy]
    links = [
        Direct("res_up-gen", reservoir_up, hydro_generator),
        Direct("gen-res_down", hydro_generator, reservoir_down),
        Direct("res_down-pump", reservoir_down, hydro_pump),
        Direct("pump-res_up", hydro_pump, reservoir_up),
        Direct("gen-market", hydro_generator, market_sale),
        Direct("market-pump", market_buy, hydro_pump),
    ]

    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T
    )
    return case, model
end

@testset "Test generator and pump" begin
    case, model = build_case_pump()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    reservoir_up = case[:nodes][1]
    reservoir_down = case[:nodes][2]
    hydro_generator = case[:nodes][3]
    hydro_pump = case[:nodes][4]
    market = case[:nodes][5]

    Power = case[:products][2]
    Water = case[:products][3]

    m = EMB.run_model(case, model, optimizer)

    # Verify that sum upflow and discharge is equal
    for sp in strategic_periods(case[:T])
        discharge = value.([m[:flow_out][hydro_generator, t, Water] for t in sp]) .* [duration(t) for t in sp]
        upflow = value.([m[:flow_in][hydro_pump, t, Water] for t in sp]) .* [duration(t) for t in sp]
        @test sum(discharge) ≈ sum(upflow) atol=1e-12
    end
end

@testset "Test generator and pump constraints" begin
    case, model = build_case_pump()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    reservoir_up = case[:nodes][1]
    reservoir_down = case[:nodes][2]
    hydro_generator = case[:nodes][3]
    hydro_pump = case[:nodes][4]
    market = case[:nodes][5]

    Power = case[:products][2]
    Water = case[:products][3]

    gen_flag = [true, false, false, false]
    push!(hydro_generator.data,
        Constraint{MinConstraintType}(
            Water,
            FixedProfile(0.6),                               # value
            OperationalProfile(gen_flag), # flag
            FixedProfile(Inf),                               # penalty
        )
    )

    pump_flag = [false, true, false, false]
    push!(hydro_pump.data,
        Constraint{MinConstraintType}(
            Water,
            FixedProfile(0.4),                               # value
            OperationalProfile(pump_flag), # flag
            FixedProfile(Inf),                               # penalty
        )
    )

    m = EMB.run_model(case, model, optimizer)

    # Verify that minimum constraint is respected
    for sp in strategic_periods(case[:T])
        gen_discharge = value.([m[:flow_out][hydro_generator, t, Water] for t in sp])
        @test (gen_discharge[1] ≥ 0.6 * 20) | (gen_discharge[1] ≈ 0.6 * 20)
        pump_discharge = value.([m[:flow_out][hydro_pump, t, Water] for t in sp])
        @test (pump_discharge[2] ≥ 0.4 * 20) | (pump_discharge[2] ≈ 0.4 * 20)
    end
end
