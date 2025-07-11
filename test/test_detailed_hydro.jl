# CO₂ has to be defined, even if not used, as it is required for the `EnergyModel` type
co2 = ResourceEmit("CO₂", 1.0)
power = ResourceCarrier("Power", 0.0)
water = ResourceCarrier("Water", 0.0)

"""
    gate_res_test_case(;data_res=Data[], data_gate=Data[])

Simple test case for testing the hydro gate and hydro reservoirs.
"""
function gate_res_test_case(;res_data=Data[], gate_data=Data[])
    # Declare the used resources
    𝒫 = [co2, power, water]

    # Variables for the individual entries of the time structure
    op_duration = [1, 1, 2, 4] # Operational period duration
    op_number = length(op_duration)   # Number of operational periods
    operational_periods = SimpleTimes(op_number, op_duration) # Assume step length is given i

    # The number of operational periods times the duration of the operational periods.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = sum(op_duration)

    # Create the time structure and global data
    𝒯 = TwoLevel(2, 1, operational_periods; op_per_strat)
    modeltype = OperationalModel(
        Dict(co2 => FixedProfile(10)),  # Emission cap for co2 in t/8h
        Dict(co2 => FixedProfile(0)),   # Emission price for co2 in EUR/t
        co2,                            # co2 instance
    )

    # Create a hydro reservoir
    hydro_reservoir = HydroReservoir{CyclicStrategic}(
        "hydro_reservoir",  # Node ID
        StorCap(
            FixedProfile(100), # vol, maximum capacity in mm3
        ),
        OperationalProfile([5, 10, 15, 20]),   # storage_inflow
        water,              # stor_res, stored resource
        res_data,           # Extension data
    )

    # Create a hydro reservoir gate
    hydro_gate = HydroGate(
        "hydro_gate",       # Node ID
        FixedProfile(100),  # cap, in mm3/timestep
        FixedProfile(0),    # opex_var, variable OPEX in EUR/(mm3/h?)
        FixedProfile(0),    # opex_fixed, Fixed OPEX in EUR/(mm3/h?)
        water,              # water resource
        gate_data,          # Extension data
    )

    # Create a hydro sink
    hydro_ocean = RefSink(
        "ocean",   # Node id
        FixedProfile(15),    # Firm demand that can't be fulfilled
        Dict(
            :surplus => FixedProfile(0),
            :deficit => OperationalProfile([0, 20, 0, 0]) # Cost for violating demand at step 2
        ),
        Dict(water => 1),   # Resource and corresponding ratio
    )

    # Create the arrays of nodes and links
    𝒩 = [hydro_reservoir, hydro_gate, hydro_ocean]
    ℒ = [
        Direct("hydro_res-hydro_gate", hydro_reservoir, hydro_gate),
        Direct("hydro_gate-ocean", hydro_gate, hydro_ocean)
    ]

    # Input data structure
    case = Case(𝒯, 𝒫, [𝒩, ℒ])
    return case, modeltype
end

@testset "HydroReservoir and HydroGate" begin
    @testset "Utlities" begin
        # Create the model and extract the data
        res_data = [ScheduleConstraint{MinSchedule}(
            nothing,
            OperationalProfile([0.2, 0.2, 0, 0]),   # value
            FixedProfile(true),                     # flag
            FixedProfile(Inf),                      # penalty
        )]
        gate_value = OperationalProfile(0.1 * ones(4))
        gate_flag = OperationalProfile([false, true, true, false])
        gate_data = [ScheduleConstraint{EqualSchedule}(
            nothing,
            gate_value,         # value
            gate_flag,          # flag
            FixedProfile(57),   # penalty
        )]
        case, _ = gate_res_test_case(;res_data, gate_data)
        𝒯 = get_time_struct(case)
        res, gate = get_nodes(case)[[1, 2]]

        # Test the schedule data
        @test isnothing(EMRP.resource(gate_data[1]))
        @test EMRP.is_constraint_resource(gate_data[1], water) == false
        @test EMRP.is_constraint_data(gate_data[1]) == true
        @test EMRP.constraint_data(gate) == gate_data
        @test all(EMRP.is_active(gate_data[1], t) == gate_flag[t] for t ∈ 𝒯)
        @test all(EMRP.value(gate_data[1], t) == gate_value[t] for t ∈ 𝒯)
        @test all(EMRP.penalty(gate_data[1], t) == 57 for t ∈ 𝒯)
        @test all(EMRP.has_penalty(gate_data[1], t) == gate_flag[t] for t ∈ 𝒯)
        @test all(!EMRP.has_penalty(res_data[1], t) for t ∈ 𝒯)
        @test EMRP.has_penalty_up(gate_data[1])
        @test EMRP.has_penalty_down(gate_data[1])
        @test EMRP.has_penalty_up(res_data[1])
        @test !EMRP.has_penalty_down(res_data[1])

        # Test the EMB utility functions
        @test level(res) == StorCap(FixedProfile(100))
        @test storage_resource(res) == water
        @test inputs(res) == [water]
        @test inputs(res, water) == 1
        @test outputs(res) == [water]
        @test outputs(res, water) == 1
        @test node_data(res) == res_data
        @test capacity(gate) == FixedProfile(100)
        @test all(capacity(gate, t) == 100 for t ∈ 𝒯)
        @test opex_var(gate) == FixedProfile(0)
        @test all(opex_var(gate, t) == 0 for t ∈ 𝒯)
        @test opex_fixed(gate) == FixedProfile(0)
        @test all(opex_fixed(gate, t) == 0 for t ∈ 𝒯)
        @test inputs(gate) == [water]
        @test inputs(gate, water) == 1
        @test outputs(gate) == [water]
        @test outputs(gate, water) == 1
        @test node_data(gate) == gate_data

        # Test the EMRP utility functions
        prof = OperationalProfile([5, 10, 15, 20])
        @test all(EMRP.vol_inflow(res)[t] == prof[t] for t ∈ 𝒯)
        @test all(EMRP.vol_inflow(res, t) == prof[t] for t ∈ 𝒯)
    end

    @testset "Without schedule constraints" begin
        # Create and solve the model
        case, modeltype = gate_res_test_case()
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        hydro_reservoir, hydro_gate = get_nodes(case)[[1, 2]]
        water = get_products(case)[3]

        @test all(value.(m[:stor_level_Δ_op][hydro_reservoir, t]) ≈
            EMRP.vol_inflow(hydro_reservoir, t) - value.(m[:flow_in][hydro_gate, t, water])
        for t ∈ 𝒯)
        @test objective_value(m) == 0
    end

    @testset "Hydro reservoir - Soft MinSchedule and hard MaxSchedule" begin
        # Modify the input data
        min_profile = OperationalProfile([0.2, 0.2, 0, 0])
        max_profile = OperationalProfile([0.2, 0.8, 0.8, 1])
        res_data = [
            ScheduleConstraint{MinSchedule}(
                nothing,
                min_profile,        # value
                FixedProfile(true), # flag
                FixedProfile(10),  # penalty
            ),
            ScheduleConstraint{MaxSchedule}(
                nothing,
                max_profile,        # value
                FixedProfile(true), # flag
                FixedProfile(Inf),  # penalty
            )
        ]

        # Create and solve the model
        case, modeltype = gate_res_test_case(;res_data)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        res, gate, sink = get_nodes(case)[[1, 2, 3]]

        # Test that extraction is working with multiple scheduling constraints data
        data = EMRP.constraint_data(res)
        @test data == res_data
        @test !EMRP.has_penalty_up(data[2])
        @test EMRP.has_penalty_down(data[2])

        # Test that the penalty variables are created, but only the up is not empty
        # - EMB.variables_node(m, 𝒩::Vector{HydroReservoir{T}}, 𝒯, modeltype::EnergyModel) where {T <: EMB.StorageBehavior}
        @test !isempty(m[:rsv_penalty_up])
        @test isempty(m[:rsv_penalty_down])

        # Test that the minimum and maximum schedules are not violated in any of the periods
        # - build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::ScheduleConstraint{MinSchedule}, 𝒯)
        # - build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::ScheduleConstraint{MaxSchedule}, 𝒯)
        @test all(
            value.(m[:stor_level][res, t] + m[:rsv_penalty_up][res, t, water]) ≥
                capacity(level(res), t) * min_profile[t]
        for t ∈ 𝒯)
        @test all(
            value.(m[:stor_level][res, t]) ≤ capacity(level(res), t) * max_profile[t]
        for t ∈ 𝒯)

        # Test that the violation is included in the OPEX, and hence, the objective has changed
        # - EMB.constraints_opex_var(m, n::HydroReservoir, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_var][res, t_inv]) ≈
                sum(value.(m[:rsv_penalty_up][res, t, water]) * 10 * duration(t) for t ∈ t_inv)
        for t_inv ∈ 𝒯ⁱⁿᵛ)
        @test objective_value(m) ≈
            -sum(
                value.(m[:sink_deficit][sink, t]) * deficit_penalty(sink, t) * duration(t) +
                value.(m[:rsv_penalty_up][res, t, water]) * 10 * duration(t)
        for t ∈ 𝒯)
        @test objective_value(m) ≈-100
    end

    @testset "Hydro reservoir - Hard MinSchedule and soft MaxSchedule" begin
        # Modify the input data
        min_profile = OperationalProfile([1, 0, 0, 0])
        max_profile = OperationalProfile([1, 0, 0.8, 1])
        penalty_cost = 57
        res_data = [
            ScheduleConstraint{MinSchedule}(
                nothing,
                min_profile,        # value
                FixedProfile(true), # flag
                FixedProfile(Inf), # penalty
            ),
            ScheduleConstraint{MaxSchedule}(
                nothing,
                max_profile,        # value
                FixedProfile(true), # flag
                FixedProfile(penalty_cost),  # penalty
            )
        ]

        # Create and solve the model
        case, modeltype = gate_res_test_case(;res_data)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        res, gate, sink = get_nodes(case)[[1, 2, 3]]

        # Test that the penalty variables are created, but only the down is not empty
        # - EMB.variables_node(m, 𝒩::Vector{<:HydroReservoir}, 𝒯, modeltype::EnergyModel)
        @test isempty(m[:rsv_penalty_up])
        @test !isempty(m[:rsv_penalty_down])

        # Test that the violations are correctly calculated
        # - build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::ScheduleConstraint{MaxSchedule}, 𝒯)
        @test all(
            value.(m[:stor_level][res, t] - m[:rsv_penalty_down][res, t, water]) ≤
                max_profile[t] * capacity(level(res), t)
        for t ∈ 𝒯)
        prof = OperationalProfile([0, 10, 0, 0])
        @test all(value.(m[:rsv_penalty_down][res, t, water]) ≈ prof[t] for t ∈ 𝒯, atol=TEST_ATOL)

        # Test that the violation is included in the OPEX, and hence, the objective has changed
        # - EMB.constraints_opex_var(m, n::HydroReservoir, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_var][res, t_inv]) ≈
                sum(value.(m[:rsv_penalty_down][res, t, water]) * penalty_cost * duration(t) for t ∈ t_inv)
        for t_inv ∈ 𝒯ⁱⁿᵛ)
        @test objective_value(m) ≈ -sum(value.(m[:opex_var][res, t_inv]) for t_inv ∈ 𝒯ⁱⁿᵛ)
        @test objective_value(m) ≈ -1140
    end

    @testset "Hydro reservoir - Hard EqualSchedule" begin
        # Modify the input data
        sched_profile = OperationalProfile([0.65, 0.3, 0.2, 0.6])
        res_data = [
            ScheduleConstraint{EqualSchedule}(
                nothing,
                sched_profile,      # value
                FixedProfile(true), # flag
                FixedProfile(Inf),  # penalty
            ),
        ]

        # Create and solve the model
        case, modeltype = gate_res_test_case(;res_data)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        res, gate, sink = get_nodes(case)[[1, 2, 3]]

        # Test that the penalty variables are created
        # - EMB.variables_node(m, 𝒩::Vector{<:HydroReservoir}, 𝒯, modeltype::EnergyModel)
        @test isempty(m[:rsv_penalty_up])
        @test isempty(m[:rsv_penalty_down])

        # Test that there are no violations
        # - EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{EqualSchedule})
        @test all(
            value.(m[:stor_level][res, t]) ≈ sched_profile[t] * capacity(level(res), t)
        for t ∈ 𝒯)
        prof = OperationalProfile([15, 0, 0, 5])
        @test all(value.(m[:sink_deficit][sink, t]) ≈ prof[t] for t ∈ 𝒯)
    end

    @testset "Hydro reservoir - Soft EqualSchedule" begin
        # Modify the input data
        sched_profile = OperationalProfile([0.8, 0.65, 0.4, 0.6])
        penalty_cost = 10
        res_data = [
            ScheduleConstraint{EqualSchedule}(
                nothing,
                sched_profile,              # value
                FixedProfile(true),         # flag
                FixedProfile(penalty_cost), # penalty
            ),
        ]

        # Create and solve the model
        case, modeltype = gate_res_test_case(;res_data)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        res, gate, sink = get_nodes(case)[[1, 2, 3]]

        # Test that the variable extraction functions are working
        @test EMRP.get_var_pen_up(m, res, 𝒯, res_data[1]) ==
            m[:rsv_penalty_up][res, :, water]
        @test EMRP.get_var_pen_down(m, res, 𝒯, res_data[1]) ==
            m[:rsv_penalty_down][res, :, water]
        @test EMRP.get_var_schedule(m, res, 𝒯, res_data[1]) == m[:stor_level][res, :]

        # Test that the penalty variables are created
        # - EMB.variables_node(m, 𝒩::Vector{<:HydroReservoir}, 𝒯, modeltype::EnergyModel)
        @test !isempty(m[:rsv_penalty_up])
        @test !isempty(m[:rsv_penalty_down])

        # Test that the violations are correctly calculated
        # - EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{EqualSchedule})
        @test all(
            value.(m[:stor_level][res, t] - m[:rsv_penalty_down][res, t, water]) ≤
                sched_profile[t] * capacity(level(res), t)
        for t ∈ 𝒯)
        @test all(value.(m[:rsv_penalty_down][res, t, water]) ≈ 0 for t ∈ 𝒯, atol=TEST_ATOL)
        @test all(
            value.(m[:stor_level][res, t] + m[:rsv_penalty_up][res, t, water]) ≥
                sched_profile[t] * capacity(level(res), t)
        for t ∈ 𝒯)
        prof = OperationalProfile([15, 5, 0, 0])
        @test all(value.(m[:rsv_penalty_up][res, t, water]) ≈ prof[t] for t ∈ 𝒯, atol=TEST_ATOL)

        # Test that the violation is included in the OPEX, and hence, the objective has changed
        # - EMB.constraints_opex_var(m, n::HydroReservoir, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_var][res, t_inv]) ≈
                sum(
                    value.(m[:rsv_penalty_down][res, t, water] + m[:rsv_penalty_up][res, t, water]) *
                penalty_cost * duration(t) for t ∈ t_inv)
        for t_inv ∈ 𝒯ⁱⁿᵛ)
        @test objective_value(m) ≈ -sum(value.(m[:opex_var][res, t_inv]) for t_inv ∈ 𝒯ⁱⁿᵛ)
        @test objective_value(m) ≈ -400
    end

    @testset "Gate - Hard EqualSchedule" begin
        # Modify the input data[5, 10, 15, 20]
        schedule_profile = OperationalProfile([0.4, 0.45, 0, 0.1])
        flags = OperationalProfile([true, true, true, true])
        gate_data = [
            ScheduleConstraint{EqualSchedule}(
                nothing,
                schedule_profile, # value
                flags,            # flag
                FixedProfile(Inf), # penalty
            )
        ]

        # Create and solve the model
        case, modeltype = gate_res_test_case(;gate_data)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        res, gate, sink = get_nodes(case)[[1, 2, 3]]
        gate_flow = value.(m[:flow_out][gate, :, water])

        # Test that the outflow is high when there are no penalties

        # Test that the penalty variables are not created
        # - EMB.variables_node(m, 𝒩::Vector{HydroGate}, 𝒯, modeltype::EnergyModel)
        @test isempty(m[:gate_penalty_up])
        @test isempty(m[:gate_penalty_down])

        # Test that there are no violations
        # - EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{EqualSchedule})
        @test all(gate_flow[t] ≈ schedule_profile[t] * capacity(gate, t) for t ∈ 𝒯)
    end

    @testset "Gate - Soft EqualSchedule, varying flags" begin
        # Modify the input data
        schedule_profile = FixedProfile(0.1)
        flags = OperationalProfile([false, true, true, false])
        penalty_cost = 57
        gate_data = [
            ScheduleConstraint{EqualSchedule}(
                nothing,
                schedule_profile, # value
                flags,            # flag
                FixedProfile(penalty_cost), # penalty
            )
        ]

        # Create and solve the model
        case, modeltype = gate_res_test_case(;gate_data)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        res, gate, sink = get_nodes(case)[[1, 2, 3]]
        gate_flow = value.(m[:flow_out][gate, :, water])

        # Test that the variable extraction functions are working
        @test EMRP.get_var_pen_up(m, gate, 𝒯, gate_data[1]) ==
            m[:gate_penalty_up][gate, :, water]
        @test EMRP.get_var_pen_down(m, gate, 𝒯, gate_data[1]) ==
            m[:gate_penalty_down][gate, :, water]
        @test EMRP.get_var_schedule(m, gate, 𝒯, gate_data[1]) == m[:flow_out][gate, :, water]

        # Test that the penalty variables are created and non-empty
        # - EMB.variables_node(m, 𝒩::Vector{HydroGate}, 𝒯, modeltype::EnergyModel)
        @test !isempty(m[:gate_penalty_up])
        @test !isempty(m[:gate_penalty_down])

        # Test that the outflow is high when there are no penalties
        prof = OperationalProfile([5, 10, 10, 22.5])
        @test all(gate_flow[t] ≈ prof[t] for t ∈ 𝒯)

        # Test that the constraint is enforced
        @test all(iszero(value.(m[:gate_penalty_up][gate, t, water])) for t ∈ 𝒯 if flags[t])
        @test all(iszero(value.(m[:gate_penalty_down][gate, t, water])) for t ∈ 𝒯 if flags[t])

        # Test that the schedule values are used, when the flag is set
        # - EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{EqualSchedule})
        @test all(gate_flow[t] ≈ schedule_profile[t]*capacity(gate, t) for t ∈ 𝒯 if flags[t])
    end

    @testset "Gate - Hard MinSchedule and soft MaxSchedule, varying penalty" begin
        # Modify the input data
        min_schedule = FixedProfile(0.1)
        max_schedule = FixedProfile(0.15)
        penalty_cost = OperationalProfile([12, 23, 57, 44])
        gate_data = [
            ScheduleConstraint{MinSchedule}(
                nothing,
                min_schedule,       # value
                FixedProfile(true), # flag
                FixedProfile(Inf),  # penalty
            )
            ScheduleConstraint{MaxSchedule}(
                nothing,
                max_schedule,       # value
                FixedProfile(true), # flag
                penalty_cost,       # penalty
            )
        ]

        # Create and solve the model
        case, modeltype = gate_res_test_case(;gate_data)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        res, gate, sink = get_nodes(case)[[1, 2, 3]]
        gate_flow = value.(m[:flow_out][gate, :, water])

        # Test that the penalty variables are created, but only the down is not empty
        # - EMB.variables_node(m, 𝒩::Vector{HydroGate}, 𝒯, modeltype::EnergyModel)
        @test isempty(m[:gate_penalty_up])
        @test !isempty(m[:gate_penalty_down])

        # Test that the down penalty is in the first periods due to the costs
        prof = OperationalProfile([5, 0, 0, 0])
        @test all(value.(m[:gate_penalty_down][gate, t, water]) ≈ prof[t] for t ∈ 𝒯)

        # Test that the deficit is correctly calculated
        # - EMB.constraints_opex_var(m, n::HydroGate, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_var][gate, t_inv]) ≈
                sum(
                    scale_op_sp(t_inv, t) * penalty_cost[t] * value.(m[:gate_penalty_down][gate, t, water])
                for t ∈ t_inv)
        for t_inv ∈ 𝒯ⁱⁿᵛ)
        @test all(value.(m[:opex_var][gate, t_inv]) ≈ 60 for t_inv ∈ 𝒯ⁱⁿᵛ)
    end

    @testset "Gate - Soft MinSchedule and hard MaxSchedule, varying penalty" begin
        # Modify the input data
        min_schedule = FixedProfile(0.16)
        max_schedule = FixedProfile(0.3)
        penalty_cost = OperationalProfile([12, 50, 57, 44])
        gate_data = [
            ScheduleConstraint{MinSchedule}(
                nothing,
                min_schedule,       # value
                FixedProfile(true), # flag
                penalty_cost,       # penalty
            )
            ScheduleConstraint{MaxSchedule}(
                nothing,
                max_schedule,       # value
                FixedProfile(true), # flag
                FixedProfile(Inf),  # penalty
            )
        ]

        # Create and solve the model
        case, modeltype = gate_res_test_case(;gate_data)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        res, gate, sink = get_nodes(case)[[1, 2, 3]]
        gate_flow = value.(m[:flow_out][gate, :, water])

        # Test that the penalty variables are created, but only the up is not empty
        # - EMB.variables_node(m, 𝒩::Vector{HydroGate}, 𝒯, modeltype::EnergyModel)
        @test !isempty(m[:gate_penalty_up])
        @test isempty(m[:gate_penalty_down])

        # Test that the down penalty is in the first periods due to the costs
        prof = OperationalProfile([3, 0, 0, 0])
        @test all(value.(m[:gate_penalty_up][gate, t, water]) ≈ prof[t] for t ∈ 𝒯)

        # Test that the deficit is correctly calculated
        # - EMB.constraints_opex_var(m, n::HydroGate, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_var][gate, t_inv]) ≈
                sum(
                    scale_op_sp(t_inv, t) * penalty_cost[t] * value.(m[:gate_penalty_up][gate, t, water])
                for t ∈ t_inv)
        for t_inv ∈ 𝒯ⁱⁿᵛ)
        @test all(value.(m[:opex_var][gate, t_inv]) ≈ 36 for t_inv ∈ 𝒯ⁱⁿᵛ)
    end
end

@testset "HydroGenerator" begin
    """
        gen_test_case(data=Data[], profit=OperationalProfile(-[10, 11, 12, 13]))

    Simple test case for testing the hydro generator, including the PQ curve implementation and
    the `ScheduleConstraint`s.
    """
    function gen_test_case(;
        data=Data[],
        profit=OperationalProfile(-[10, 11, 12, 13]),
    )
        case, modeltype = gate_res_test_case()
        power, water = get_products(case)[[2, 3]]
        hydro_gen_cap = 20
        gen = HydroGenerator(
            "hydro_generator", # Node ID
            FixedProfile(hydro_gen_cap),    # Installed power capacity
            PqPoints(
                [0, 10, 20] / hydro_gen_cap,
                [0, 10, 22] / hydro_gen_cap
            ),          # PQ-curve
            FixedProfile(0),   # opex_var
            FixedProfile(0),   # opex_fixed
            power,
            water,
            data,
        )

        el_market = RefSink(
            "market",
            FixedProfile(0),
            Dict(
                :surplus => profit,
                :deficit => FixedProfile(1000)
            ),
            Dict(power => 1.0),
            Data[]
        )

        res, water_sink = get_nodes(case)[[1, 3]]

        # Update the nodes and links
        push!(get_nodes(case), gen)
        push!(get_nodes(case), el_market)

        push!(get_links(case), Direct("hydro_res-hydro_gen", res, gen))
        push!(get_links(case), Direct("hydro_gen-water_sink", gen, water_sink))
        push!(get_links(case), Direct("hydro_gen-market", gen, el_market))

        return case, modeltype
    end

    @testset "Utlities" begin
        # Create the model and extract the data
        val = OperationalProfile(0.1 * ones(4))
        flag = OperationalProfile([false, true, true, false])
        data = [ScheduleConstraint{EqualSchedule}(
            water,
            val,                # value
            flag,               # flag
            FixedProfile(57),   # penalty
        )]
        case, _ = gen_test_case(;data)
        𝒯 = get_time_struct(case)
        gen = get_nodes(case)[4]

        # Test the schedule data
        @test EMRP.resource(data[1]) == water
        @test EMRP.is_constraint_resource(data[1], water)
        @test !EMRP.is_constraint_resource(data[1], power)
        @test EMRP.is_constraint_data(data[1]) == true
        @test !EMRP.is_constraint_resource(data[1], power)
        @test EMRP.constraint_data(gen) == data
        @test all(EMRP.is_active(data[1], t) == flag[t] for t ∈ 𝒯)
        @test all(EMRP.value(data[1], t) == val[t] for t ∈ 𝒯)
        @test all(EMRP.penalty(data[1], t) == 57 for t ∈ 𝒯)
        @test all(EMRP.has_penalty(data[1], t) == flag[t] for t ∈ 𝒯)
        @test EMRP.has_penalty_up(data[1])
        @test EMRP.has_penalty_down(data[1])

        # Test the EMB utility functions
        @test capacity(gen) == FixedProfile(20)
        @test all(capacity(gen, t) == 20 for t ∈ 𝒯)
        @test opex_var(gen) == FixedProfile(0)
        @test all(opex_var(gen, t) == 0 for t ∈ 𝒯)
        @test opex_fixed(gen) == FixedProfile(0)
        @test all(opex_fixed(gen, t) == 0 for t ∈ 𝒯)
        @test inputs(gen) == [water]
        @test inputs(gen, water) == 1
        @test all(p ∈ [water, power] for p ∈ outputs(gen))
        @test all(val == 1 for p ∈ outputs(gen) for val ∈ outputs(gen, p))
        @test node_data(gen) == data

        # Test the EMRP utility functions
        @test EMRP.max_normalized_power(gen) == 1
        @test EMRP.max_normalized_flow(gen) == 1.1
        @test EMRP.water_resource(gen) == water
        @test EMRP.electricity_resource(gen) == power
        pq_val = EMRP.pq_curve(gen)
        @test EMRP.power_level(pq_val) == [0, 10, 20] / 20
        @test EMRP.power_level(pq_val, 2) == 0.5
        @test EMRP.discharge_level(pq_val) == [0, 10, 22] / 20
        @test EMRP.discharge_level(pq_val, 3) == 1.1
        @test EMRP.discharge_segments(pq_val) == range(1, 2)
    end

    @testset "Plant production and PQ relation" begin
        # Create and solve the model
        case, modeltype = gen_test_case()
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        gate, sink, gen = get_nodes(case)[2:4]
        pq_val = EMRP.pq_curve(gen)
        gen_out = value.(m[:flow_out][gen, :, :])

        # Test that the penalty variables are not created except for discharge_segments
        # - EMB.variables_node(m, 𝒩::Vector{HydroUnit}, 𝒯, modeltype::EnergyModel)
        @test isempty(m[:gen_penalty_up])
        @test isempty(m[:gen_penalty_down])
        @test !isempty(m[:discharge_segment][gen, :, :])
        @test all(length(m[:discharge_segment][gen, t, :]) == 2  for t ∈ 𝒯)

        # Check that the total capacity constraint is enforced
        # - EMB.constraints_capacity(m, n::HydroUnit, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:cap_use])[gen, t] ≤
                value.(m[:cap_inst])[gen, t] * EMRP.max_normalized_power(gen)
        for t ∈ 𝒯)

        # Check that the discharge segments are correctly calculated
        # - build_pq_constaints(m, n::HydroUnit, pq::PqPoints, 𝒯::TimeStructure)
        Q = EMRP.discharge_segments(pq_val)
        η = [
            (EMRP.power_level(pq_val, q+1) - EMRP.power_level(pq_val, q)) /
            (EMRP.discharge_level(pq_val, q+1) - EMRP.discharge_level(pq_val, q))
        for q ∈ Q]
        @test all(
            value.(m[:discharge_segment])[gen, t, q] ≤
                capacity(gen, t) * (EMRP.discharge_level(pq_val, q+1) - EMRP.discharge_level(pq_val, q))
        for t ∈ 𝒯, q ∈ Q)
        @test all(
            gen_out[t, water] ≈
                sum(value.(m[:discharge_segment])[gen, t, q] for q ∈ Q)
        for t ∈ 𝒯)
        @test all(
            value.(m[:cap_use])[gen, t] ≈
                sum(value.(m[:discharge_segment])[gen, t, q] * η[q] for q ∈ Q)
        for t ∈ 𝒯)
        prod_to_discharge = Interpolations.linear_interpolation(
            EMRP.power_level(pq_val) * 20,
            EMRP.discharge_level(pq_val) * 20
        )
        @test all(
            gen_out[t, water] ≈ prod_to_discharge(gen_out[t, power])
        for t ∈ 𝒯)

        # Check that the hydro flow balance is enforced
        # - EMB.constraints_flow_in(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(gen_out[t, water] ≈ value.(m[:flow_in])[gen, t, water] for t ∈ 𝒯)

        # Check that the electricity balance is enforced
        # - EMB.constraints_flow_out(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(gen_out[t, power] ≈ value.(m[:cap_use][gen, t]) for t ∈ 𝒯)
    end

    @testset "Hard EqualSchedule for power" begin
        # Modify the input data
        schedule_profile = OperationalProfile(0.8 * ones(4))
        schedule_flag = OperationalProfile([false, false, true, true])
        data = [
            ScheduleConstraint{EqualSchedule}(
                power,
                schedule_profile,   # value
                schedule_flag,      # flag
                FixedProfile(Inf),  # penalty
            )
        ]
        profit = OperationalProfile(-[50, 50, 10, 10])

        # Create and solve the model
        case, modeltype = gen_test_case(; data, profit)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        gate, sink, gen = get_nodes(case)[2:4]
        pq_val = EMRP.pq_curve(gen)
        gen_out = value.(m[:flow_out][gen, :, :])

        # Test that the penalty variables are not created except for discharge_segments
        # - EMB.variables_node(m, 𝒩::Vector{HydroUnit}, 𝒯, modeltype::EnergyModel)
        @test isempty(m[:gen_penalty_up])
        @test isempty(m[:gen_penalty_down])
        @test !isempty(m[:discharge_segment][gen, :, :])
        @test all(length(m[:discharge_segment][gen, t, :]) == 2  for t ∈ 𝒯)

        # Test that there are no violations
        # - EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{EqualSchedule})
        @test all(gen_out[t, power] ≈ schedule_profile[t] * capacity(gen, t) for t ∈ 𝒯 if schedule_flag[t])
    end

    @testset "Soft EqualSchedule for power" begin
        # Modify the input data
        schedule_profile = OperationalProfile(0.8 * ones(4))
        schedule_flag = OperationalProfile([false, false, true, true])
        data = [
            ScheduleConstraint{EqualSchedule}(
                power,
                schedule_profile,   # value
                schedule_flag,      # flag
                FixedProfile(200),  # penalty
            )
        ]
        profit = OperationalProfile(-[50, 50, 10, 10])

        # Create and solve the model
        case, modeltype = gen_test_case(; data, profit)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        gate, sink, gen = get_nodes(case)[2:4]
        pq_val = EMRP.pq_curve(gen)
        gen_out = value.(m[:flow_out][gen, :, :])

        # Test that the penalty variables are created including discharge_segments
        # - EMB.variables_node(m, 𝒩::Vector{HydroUnit}, 𝒯, modeltype::EnergyModel)
        @test !isempty(m[:gen_penalty_up])
        @test !isempty(m[:gen_penalty_down])
        @test !isempty(m[:discharge_segment][gen, :, :])
        @test all(length(m[:discharge_segment][gen, t, :]) == 2  for t ∈ 𝒯)

        # Test that the variable extraction functions are working
        @test EMRP.get_var_pen_up(m, gen, 𝒯, data[1]) ==
            m[:gen_penalty_up][gen, :, power]
        @test EMRP.get_var_pen_down(m, gen, 𝒯, data[1]) ==
            m[:gen_penalty_down][gen, :, power]
        @test EMRP.get_var_schedule(m, gen, 𝒯, data[1]) == m[:flow_out][gen, :, power]

        # Test that there are no violations and the outflow variables are not fixed
        # - EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{EqualSchedule})
        @test all(gen_out[t, power] ≈ schedule_profile[t] * capacity(gen, t) for t ∈ 𝒯 if schedule_flag[t])
        @test all(!is_fixed(m[:flow_out][gen, t, power]) for t ∈ 𝒯)
    end

    @testset "Soft MinSchedule for water" begin
        # Modify the input data
        schedule_profile = FixedProfile(0.5)
        schedule_flag = FixedProfile(true)
        data = [
            ScheduleConstraint{EqualSchedule}(
                water,
                schedule_profile,   # value
                schedule_flag,      # flag
                FixedProfile(50),   # penalty
            )
        ]

        # Create and solve the model
        case, modeltype = gen_test_case(; data)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        gate, sink, gen = get_nodes(case)[2:4]
        pq_val = EMRP.pq_curve(gen)
        gen_out = value.(m[:flow_out][gen, :, :])

        # Test that the penalty variables are created
        # - EMB.variables_node(m, 𝒩::Vector{HydroUnit}, 𝒯, modeltype::EnergyModel)
        @test !isempty(m[:gen_penalty_up])
        @test !isempty(m[:gen_penalty_down])

        # Test that outflow is constrained due to the large penalty
        # - EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{EqualSchedule})
        @test all(gen_out[t, water] ≈ schedule_profile[t] * capacity(gen, t) * 1.1 for t ∈ 𝒯)
    end
end

@testset "HydroPump" begin
    """
        pump_test_case(; pump_data=Data[], gen_data=Data[])

    Simple test case for testing the hydro pump, including the PQ curve implementation and
    the `ScheduleConstraint`s.
    """
    function pump_test_case(; pump_data=Data[], gen_data=Data[])
        # Declare the used resources
        𝒫 = [co2, power, water]

        # Variables for the individual entries of the time structure
        op_duration = [1, 1, 2, 4] # Operational period duration
        op_number = length(op_duration)   # Number of operational periods
        operational_periods = SimpleTimes(op_number, op_duration) # Assume step length is given i

        # The number of operational periods times the duration of the operational periods.
        # This implies, that a strategic period is 8 times longer than an operational period,
        # resulting in the values below as "/8h".
        op_per_strat = sum(op_duration)

        # Create the time structure and global data
        𝒯 = TwoLevel(2, 1, operational_periods; op_per_strat)
        modeltype = OperationalModel(
            Dict(co2 => FixedProfile(10)),  # Emission cap for co2 in t/8h
            Dict(co2 => FixedProfile(0)),   # Emission price for co2 in EUR/t
            co2,                            # co2 instance
        )

        # Create a hydro reservoir
        reservoir_up = HydroReservoir{CyclicStrategic}(
            "hydro_reservoir_up",  # Node ID
            StorCap(
                FixedProfile(100), # vol, maximum capacity in mm3
            ),
            OperationalProfile([0, 0, 0, 0]),   # storage_inflow
            water,              # stor_res, stored resource
        )
        reservoir_down = HydroReservoir{CyclicStrategic}(
            "hydro_reservoir_down",  # Node ID
            StorCap(
                FixedProfile(100), # vol, maximum capacity in mm3
            ),
            OperationalProfile([0, 0, 0, 0]),   # storage_inflow
            water,              # stor_res, stored resource
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
            power,
            water,
            gen_data
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
            power,
            water,
            pump_data
        )

        market_sale = RefSink(
            "market",
            FixedProfile(0),
            Dict(
                :surplus => OperationalProfile(-[10, 60, 15, 65]),
                :deficit => FixedProfile(1000)
            ),
            Dict(power => 1.0),
        )

        market_buy = RefSource(
            "market_buy",
            FixedProfile(1000),
            OperationalProfile([10, 60, 15, 65]),
            FixedProfile(0),
            Dict(power => 1.0),
        )

        # Create the array of nodes and the links
        𝒩 = [reservoir_up, reservoir_down, hydro_generator, hydro_pump, market_sale, market_buy]
        ℒ = [
            Direct("res_up-gen", reservoir_up, hydro_generator),
            Direct("gen-res_down", hydro_generator, reservoir_down),
            Direct("res_down-pump", reservoir_down, hydro_pump),
            Direct("pump-res_up", hydro_pump, reservoir_up),
            Direct("gen-market", hydro_generator, market_sale),
            Direct("market-pump", market_buy, hydro_pump),
        ]

        # Input data structure
        case = Case(𝒯, 𝒫, [𝒩, ℒ])
        return case, modeltype
    end

    @testset "Utlities" begin
        # Create the model and extract the data
        val = OperationalProfile(0.1 * ones(4))
        pump_flag = OperationalProfile([false, true, true, false])
        pump_data = [ScheduleConstraint{MinSchedule}(
            water,
            FixedProfile(0.4),      # value
            pump_flag,              # flag
            FixedProfile(Inf),      # penalty
        )]
        case, _ = pump_test_case(;pump_data)
        𝒯 = get_time_struct(case)
        pump = get_nodes(case)[4]

        # Test the schedule pump_data
        @test EMRP.resource(pump_data[1]) == water
        @test EMRP.is_constraint_resource(pump_data[1], water)
        @test !EMRP.is_constraint_resource(pump_data[1], power)
        @test EMRP.is_constraint_data(pump_data[1]) == true
        @test !EMRP.is_constraint_resource(pump_data[1], power)
        @test EMRP.constraint_data(pump) == pump_data
        @test all(EMRP.is_active(pump_data[1], t) == pump_flag[t] for t ∈ 𝒯)
        @test all(EMRP.value(pump_data[1], t) == 0.4 for t ∈ 𝒯)
        @test all(EMRP.penalty(pump_data[1], t) == Inf for t ∈ 𝒯)
        @test all(!EMRP.has_penalty(pump_data[1], t) for t ∈ 𝒯)
        @test EMRP.has_penalty_up(pump_data[1])
        @test !EMRP.has_penalty_down(pump_data[1])

        # Test the EMB utility functions
        @test capacity(pump) == FixedProfile(30)
        @test all(capacity(pump, t) == 30 for t ∈ 𝒯)
        @test opex_var(pump) == FixedProfile(0)
        @test all(opex_var(pump, t) == 0 for t ∈ 𝒯)
        @test opex_fixed(pump) == FixedProfile(0)
        @test all(opex_fixed(pump, t) == 0 for t ∈ 𝒯)
        @test outputs(pump) == [water]
        @test outputs(pump, water) == 1
        @test all(p ∈ [water, power] for p ∈ inputs(pump))
        @test all(val == 1 for p ∈ inputs(pump) for val ∈ inputs(pump, p))
        @test node_data(pump) == pump_data

        # Test the EMRP utility functions
        @test EMRP.max_normalized_power(pump) == 1
        @test EMRP.max_normalized_flow(pump) == 2/3
        @test EMRP.water_resource(pump) == water
        @test EMRP.electricity_resource(pump) == power
    end

    @testset "No production constraints" begin
        # Create and solve the model
        case, modeltype = pump_test_case()
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the pump_data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        gen, pump = get_nodes(case)[3:4]
        pq_val = EMRP.pq_curve(pump)
        gen_out = value.(m[:flow_out][gen, :, :])
        pump_in = value.(m[:flow_in][pump, :, :])
        pump_out = value.(m[:flow_out][pump, :, :])

        # Test that the penalty variables are not created except for discharge_segments
        # - EMB.variables_node(m, 𝒩::Vector{HydroUnit}, 𝒯, modeltype::EnergyModel)
        @test isempty(m[:gen_penalty_up])
        @test isempty(m[:gen_penalty_down])
        @test !isempty(m[:discharge_segment][pump, :, :])
        @test all(length(m[:discharge_segment][pump, t, :]) == 2  for t ∈ 𝒯)

        # Check that the total capacity constraint is enforced
        # - EMB.constraints_capacity(m, n::HydroUnit, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:cap_use])[pump, t] ≤
                value.(m[:cap_inst])[pump, t] * EMRP.max_normalized_power(pump)
        for t ∈ 𝒯)

        # Check that the discharge segments are correctly calculated
        # - build_pq_constaints(m, n::HydroUnit, pq::PqPoints, 𝒯::TimeStructure)
        Q = EMRP.discharge_segments(pq_val)
        η = [
            (EMRP.power_level(pq_val, q+1) - EMRP.power_level(pq_val, q)) /
            (EMRP.discharge_level(pq_val, q+1) - EMRP.discharge_level(pq_val, q))
        for q ∈ Q]
        @test all(
            value.(m[:discharge_segment])[pump, t, q] ≤
                capacity(pump, t) * (EMRP.discharge_level(pq_val, q+1) - EMRP.discharge_level(pq_val, q))
        for t ∈ 𝒯, q ∈ Q)
        @test all(
            pump_out[t, water] ≈
                sum(value.(m[:discharge_segment])[pump, t, q] for q ∈ Q)
        for t ∈ 𝒯)
        @test all(
            value.(m[:cap_use])[pump, t] ≈
                sum(value.(m[:discharge_segment])[pump, t, q] * η[q] for q ∈ Q)
        for t ∈ 𝒯)
        prod_to_discharge = Interpolations.linear_interpolation(
            EMRP.power_level(pq_val) * 30,
            EMRP.discharge_level(pq_val) * 30
        )
        @test all(
            pump_in[t, water] ≈ prod_to_discharge(pump_in[t, power])
        for t ∈ 𝒯)

        # Check that the hydro flow balance is enforced
        # - EMB.constraints_flow_in(m, n::HydroPump, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(pump_in[t, power] ≈ value.(m[:cap_use][pump, t]) for t ∈ 𝒯)

        # Check that the electricity balance is enforced
        # - EMB.constraints_flow_out(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(pump_out[t, water] ≈ pump_out[t, water] for t ∈ 𝒯)

        # Check that as much is pumped up as used for generation
        @test sum(pump_in[t, water] * duration(t) for t ∈ 𝒯) ≈
            sum(gen_out[t, water] * duration(t) for t ∈ 𝒯)
    end

    @testset "Hard MinSchedule for water" begin
        # Modify the input data
        gen_flag = OperationalProfile([true, false, false, false])
        gen_data = [ScheduleConstraint{MinSchedule}(
            water,
            FixedProfile(0.6),  # value
            gen_flag,           # flag
            FixedProfile(Inf),  # penalty
        )]
        pump_flag = OperationalProfile([false, true, false, false])
        pump_data = [ScheduleConstraint{MinSchedule}(
            water,
            FixedProfile(0.4),  # value
            pump_flag,          # flag
            FixedProfile(Inf),  # penalty
        )]

        # Create and solve the model
        case, modeltype = pump_test_case(; gen_data, pump_data)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the pump_data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        gen, pump = get_nodes(case)[3:4]
        pq_val = EMRP.pq_curve(pump)
        gen_out = value.(m[:flow_out][gen, :, :])
        pump_in = value.(m[:flow_in][pump, :, :])
        pump_out = value.(m[:flow_out][pump, :, :])

        # Test that the penalty variables are not created except for discharge_segments
        # - EMB.variables_node(m, 𝒩::Vector{HydroUnit}, 𝒯, modeltype::EnergyModel)
        @test isempty(m[:gen_penalty_up])
        @test isempty(m[:gen_penalty_down])
        @test !isempty(m[:discharge_segment][pump, :, :])
        @test all(length(m[:discharge_segment][pump, t, :]) == 2  for t ∈ 𝒯)

        # Test that there are no violations on the scheduling constraints
        # - EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{EqualSchedule})
        @test all(gen_out[t, water] ≥ 0.6 * capacity(gen, t) for t ∈ 𝒯 if gen_flag[t])
        @test all(pump_out[t, water] ≥ 0.4 * capacity(pump, t)*2/3 for t ∈ 𝒯 if pump_flag[t])
    end
    @testset "Soft MinSchedule for water" begin
        # Modify the input data
        gen_flag = OperationalProfile([true, false, false, false])
        gen_data = [ScheduleConstraint{MinSchedule}(
            water,
            FixedProfile(0.6),  # value
            gen_flag,           # flag
            FixedProfile(Inf),  # penalty
        )]
        pump_flag = OperationalProfile([false, true, false, false])
        pump_data = [ScheduleConstraint{EqualSchedule}(
            water,
            FixedProfile(0.4),  # value
            pump_flag,          # flag
            FixedProfile(50),  # penalty
        )]

        # Create and solve the model
        case, modeltype = pump_test_case(; gen_data, pump_data)
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extract the pump_data
        𝒯 = get_time_struct(case)
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)
        gen, pump = get_nodes(case)[3:4]
        pq_val = EMRP.pq_curve(pump)
        gen_out = value.(m[:flow_out][gen, :, :])
        pump_in = value.(m[:flow_in][pump, :, :])
        pump_out = value.(m[:flow_out][pump, :, :])

        # Test that the penalty variables are created, including discharge_segments
        # - EMB.variables_node(m, 𝒩::Vector{HydroUnit}, 𝒯, modeltype::EnergyModel)
        @test !isempty(m[:gen_penalty_up])
        @test !isempty(m[:gen_penalty_down])
        @test !isempty(m[:discharge_segment][pump, :, :])
        @test all(length(m[:discharge_segment][pump, t, :]) == 2  for t ∈ 𝒯)

        # Test that the variable extraction functions are working
        @test EMRP.get_var_pen_up(m, pump, 𝒯, pump_data[1]) ==
            m[:gen_penalty_up][pump, :, water]
        @test EMRP.get_var_pen_down(m, pump, 𝒯, pump_data[1]) ==
            m[:gen_penalty_down][pump, :, water]
        @test EMRP.get_var_schedule(m, pump, 𝒯, pump_data[1]) == m[:flow_in][pump, :, water]

        # Test that there are no violations on the scheduling constraints
        # - EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{EqualSchedule})
        @test all(gen_out[t, water] ≥ 0.6 * capacity(gen, t) * 2/3 for t ∈ 𝒯 if gen_flag[t])
        @test all(pump_out[t, water] ≥ 0.4 * capacity(pump, t) * 2/3 for t ∈ 𝒯 if pump_flag[t])
    end
end
