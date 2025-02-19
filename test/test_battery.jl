function general_battery_tests(m, case)
    # Extract the data
    𝒯 = get_time_struct(case)
    stor = get_nodes(case)[2]

    # Test that the level balance is correct for standard periods
    @test all(
        isapprox(
            value.(m[:stor_level][stor, t]),
                value.(m[:stor_level][stor, t_prev]) +
                value.(m[:stor_level_Δ_op][stor, t]) * duration(t),
        atol = TEST_ATOL)
    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev))

    # Test that the changes in the storage level is correctly calculated
    @test all(
        isapprox(
        value.(m[:stor_level_Δ_op][stor, t]),
            value.(m[:stor_charge_use][stor, t]) * 0.9 -
            value.(m[:stor_discharge_use][stor, t]) / 0.9,
            atol = TEST_ATOL)
    for t ∈ 𝒯)

    # Test that the outlet flow is correctly calculated.
    # The inlet flow is based on the standard approach
    @test all(
        value.(m[:flow_out][stor, t, Power]) ≈
            value.(m[:stor_discharge_use][stor, t])
    for t ∈ 𝒯)
end

@testset "Battery" begin

    using EnergyModelsInvestments
    function small_graph(
        supply_price,
        el_demand;
        ops = SimpleTimes(10, [6, 3, 6, 3, 6, 6, 3, 6, 3, 6]),
        bat_life = InfLife(),
        n_sp = 2,
        investment = false,
        data = Data[],
    )

        # Creation of the modeltype and investment data, if provided
        if investment
            modeltype = InvestmentModel(
                Dict(CO2 => FixedProfile(10)),
                Dict(CO2 => FixedProfile(0)),
                CO2,
                0.07,
            )
        else
            modeltype = OperationalModel(
                Dict(CO2 => FixedProfile(10)),
                Dict(CO2 => FixedProfile(0)),
                CO2,
            )
        end
        products = [Power, CO2]
        # Creation of the source and sink module as well as the arrays used for nodes and links
        source = RefSource(
            "power_source",
            FixedProfile(20),
            supply_price,
            FixedProfile(1),
            Dict(Power => 1),
        )
        battery = Battery{CyclicRepresentative}(
            "battery",
            StorCap(FixedProfile(20)),
            StorCap(FixedProfile(50)),
            StorCap(FixedProfile(20)),
            Power,
            Dict(Power => 0.9),
            Dict(Power => 0.9),
            bat_life,
            data
        )
        sink = RefSink(
            "power_demand",
            el_demand,
            Dict(:surplus => FixedProfile(0), :deficit => StrategicProfile([1e3,2e2])),
            Dict(Power => 1),
        )

        nodes = [source, battery, sink]
        links = [
            Direct("source-sink", nodes[1], nodes[3])
            Direct("source-bat", nodes[1], nodes[2])
            Direct("bat-sink", nodes[2], nodes[3])
        ]

        # Creation of the time structure
        op_per_strat = 8760.0
        T = TwoLevel(n_sp, 2, ops; op_per_strat)

        # Input data structure
        case = Case(T, products, [nodes, links], [[get_nodes, get_links]])

        # Creation and solving of the model
        m = create_model(case, modeltype)
        set_optimizer(m, OPTIMIZER)
        optimize!(m)

        return m, case, modeltype
    end

    function battery_prev_usage_tests(m, case)
        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        stor = get_nodes(case)[2]
        # Test that the charge usage is correctly calculated and accounting for the length of
        # both operational and strategic periods in the first operational period of a
        # strategic period
        # - constraints_usage(m, n::AbstractBattery, 𝒯, modeltype::EnergyModel)
        # - previous_usage
        t_sp1 = first(𝒯ᴵⁿᵛ[1])
        # The previous use in the first operational period of the first strategic period
        # equals the change in the operational level through charging with an efficiency of
        # 0.9 and its duration
        @test value.(m[:bat_prev_use][stor, t_sp1]) ≈
            value.(m[:stor_charge_use])[stor, t_sp1] * 0.9 * duration(t_sp1)
        t_sp2 = first(𝒯ᴵⁿᵛ[2])
        # The previous use in the first operational period of the second strategic period
        # is given by
        @test value.(m[:bat_prev_use][stor, t_sp2]) ≈
            # The initial usage at the beginning of the first operational period in the first
            # strategic period, hence the substraction
            value.(m[:bat_prev_use][stor, t_sp1]) -
            value.(m[:stor_charge_use])[stor, t_sp1] * 0.9 * duration(t_sp1) +
            # The total use in the first strategic period times its duration (value of 2)
            2 * value.(m[:bat_use_sp][stor, first(𝒯ᴵⁿᵛ)]) +
            # the change in the operational level through charging with an efficiency of
            # 0.9 and its duration
            value.(m[:stor_charge_use])[stor, t_sp2] * 0.9 * duration(t_sp2)

        # Test that the previous usage is correctly calculated in each individual operational
        # period that does have a previous period
        @test all(
            value.(m[:bat_prev_use][stor, t]) ≈
                value.(m[:bat_prev_use][stor, t_prev]) +
                value.(m[:stor_charge_use])[stor, t] * 0.9 * duration(t)
        for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev))
    end

    function battery_degradation_tests(m, case)
        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        stor, sink = get_nodes(case)[[2, 3]]

        # Test that the capacity limit is correctly enforced in the complete horizon
        # - constraints_usage_iterate:
        #   - Division by 50 to account for the installed storage capacity of the battery
        #   - Multiplication with 2 to account for the duration of the strategic period
        #   - The value of 900 correspondsd to the cycle numbers
        @test sum(value.(m[:bat_use_sp])) / 50 * 2 ≤ 900

        # Test that the capacity limit is correctly enforced in the individual operational
        # periods
        # - capacity_reduction and constraints_capacity:
        #   - The value of 50 corresponds to the installed storage capacity of the battery
        #   - The value of 0.8 corresponds to 1-the final degradation percentage
        #   - The value of 900 correspondsd to the cycle numbers
        @test all(
            value.(m[:stor_level][stor, t]) ≤
                50 - 0.2 * value.(m[:bat_prev_use][stor, t]) / 900
        for t ∈ 𝒯)

        # Test that the total deficit is smaller in the first strategic period due to the
        # larger storage size
        @test sum(value.(m[:sink_deficit][sink, t]) * duration(t) for t ∈ 𝒯ᴵⁿᵛ[1]) <
            sum(value.(m[:sink_deficit][sink, t]) * duration(t) for t ∈ 𝒯ᴵⁿᵛ[2])
    end

    # Modelling of two days with typical demand and price profiles
    el_demand = OperationalProfile([16; 28; 20; 25; 18; 15; 25; 20; 28; 18])
    supply_price = OperationalProfile([30; 80; 60; 80; 40; 30; 80; 60; 80; 40])

    @testset "SimpleTimes - No cycle limit" begin
        m, case, modeltype = small_graph(supply_price, el_demand)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        stor = get_nodes(case)[2]

        # Run the standard tests
        general_battery_tests(m, case)
        battery_prev_usage_tests(m, case)

        # Test that the level balance is correct in the first operational periods of each
        # strategic period
        @test all(
                value.(m[:stor_level][stor, first(t_inv)]) ≈
                    value.(m[:stor_level][stor, last(t_inv)]) +
                    value.(m[:stor_level_Δ_op][stor, first(t_inv)]) * duration(first(t_inv))
            for t_inv ∈ 𝒯ᴵⁿᵛ
        )
    end
    @testset "SimpleTimes - Cycle limit" begin
        bat_life = CycleLife(900, 0.2, FixedProfile(2e4))
        m, case, modeltype = small_graph(supply_price, el_demand; bat_life)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        stor, sink = get_nodes(case)[[2, 3]]

        # Run the standard tests
        general_battery_tests(m, case)
        battery_prev_usage_tests(m, case)
        battery_degradation_tests(m, case)
    end

    @testset "SimpleTimes - Cycle limit, reinvest" begin
        bat_life = CycleLife(900, 0.2, StrategicProfile([2e5, 1e5, 2e4, 2e4]))
        m, case, modeltype = small_graph(supply_price, el_demand; bat_life, n_sp=4)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        stor, sink = get_nodes(case)[[2, 3]]

        # Run the standard tests
        general_battery_tests(m, case)
        battery_prev_usage_tests(m, case)

        # Test that the capacity limit is correctly enforced in the individual operational
        # periods
        # - capacity_reduction and constraints_capacity:
        #   - The value of 50 corresponds to the installed storage capacity of the battery
        #   - The value of 0.8 corresponds to 1-the final degradation percentage
        #   - The value of 900 correspondsd to the cycle numbers
        @test all(
            value.(m[:stor_level][stor, t]) ≤
                50 - 0.2 * value.(m[:bat_prev_use][stor, t]) / 900
        for t ∈ 𝒯)

        # Test that battery stack replacement occurs once and the cost is correctly included
        @test sum(value.(m[:bat_stack_replace_b][stor, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 1
        # - constraints_opex_fixed(m, n::AbstractBattery, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        #   - 50 is the capacity
        #   - 2e4 is the cost for replacement
        #   - /2 to account for the duration of a strategic period
        @test sum(value.(m[:opex_fixed][stor, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 50 * 2e4 / 2
    end

    @testset "SimpleTimes - Cycle limit, investments, but not data" begin
        bat_life = CycleLife(900, 0.2, StrategicProfile([2e5, 1e5, 2e4, 2e4]))
        n_sp = 4
        m, case, modeltype = small_graph(
            supply_price, el_demand;
            bat_life, n_sp, investment=true,
        )

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        stor, sink = get_nodes(case)[[2, 3]]

        # Run the standard tests
        general_battery_tests(m, case)
        battery_prev_usage_tests(m, case)

        # Test that the capacity limit is correctly enforced in the individual operational
        # periods
        # - capacity_reduction and constraints_capacity:
        #   - The value of 50 corresponds to the installed storage capacity of the battery
        #   - The value of 0.8 corresponds to 1-the final degradation percentage
        #   - The value of 900 correspondsd to the cycle numbers
        @test all(
            value.(m[:stor_level][stor, t]) ≤
                50 - 0.2 * value.(m[:bat_prev_use][stor, t]) / 900 + TEST_ATOL
        for t ∈ 𝒯)

        # Test that battery stack replacement occurs once and the cost is correctly included
        @test sum(value.(m[:bat_stack_replace_b][stor, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 1
        # - constraints_opex_fixed(m, n::AbstractBattery, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        #   - 50 is the capacity
        #   - 2e4 is the cost for replacement
        #   - /2 to account for the duration of a strategic period
        @test sum(value.(m[:opex_fixed][stor, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 50 * 2e4 / 2
    end

    @testset "SimpleTimes - Cycle limit, investments and reinvest" begin
        bat_life = CycleLife(900, 0.2, StrategicProfile([2e5, 1e5, 2e4, 2e4]))
        n_sp = 4
        sp_val = zeros(n_sp)
        sp_val[1] = 50
        data = [StorageInvData(
            level = StartInvData(
                FixedProfile(2e4),
                FixedProfile(60),
                FixedProfile(0),
                ContinuousInvestment(FixedProfile(0), StrategicProfile(sp_val)),
            )
        )]
        m, case, modeltype = small_graph(
            supply_price, el_demand;
            bat_life, n_sp, investment=true, data
        )

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        stor, sink = get_nodes(case)[[2, 3]]

        # Run the standard tests
        general_battery_tests(m, case)
        battery_prev_usage_tests(m, case)

        # Test that the capacity limit is correctly enforced in the individual operational
        # periods
        # - capacity_reduction and constraints_capacity:
        #   - The value of 50 corresponds to the installed storage capacity of the battery
        #   - The value of 0.8 corresponds to 1-the final degradation percentage
        #   - The value of 900 correspondsd to the cycle numbers
        @test all(
            value.(m[:stor_level][stor, t]) ≤
                50 - 0.2 * value.(m[:bat_prev_use][stor, t]) / 900 + TEST_ATOL
        for t ∈ 𝒯)

        # Test that battery stack replacement occurs once and the cost is correctly included
        @test sum(value.(m[:bat_stack_replace_b][stor, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 1
        # - constraints_opex_fixed(m, n::AbstractBattery, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        #   - 50 is the capacity
        #   - 2e4 is the cost for replacement
        #   - /2 to account for the duration of a strategic period
        @test sum(value.(m[:opex_fixed][stor, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 50 * 2e4 / 2
    end

    # Modelling of two days as one representative period each with typical demand and price
    # profiles
    ops = RepresentativePeriods(
        2,          # Number of representative periods
        8760,       # Total duration in a strategic period
        [0.5, 0.5], # Probability of each representative period
        [
            SimpleTimes(5, [6, 3, 6, 3, 6]),
            SimpleTimes(5, [6, 3, 6, 3, 6]),
        ]
    );
    el_demand = RepresentativeProfile([
        OperationalProfile([16; 29; 20; 25; 17]);
        OperationalProfile([15; 26; 20; 28; 18]);
    ])
    supply_price = OperationalProfile([30; 80; 60; 80; 40])

    @testset "RepresentativePeriods - No cycle limit" begin
        m, case, modeltype = small_graph(supply_price, el_demand; ops)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        stor = get_nodes(case)[2]

        # Run the standard tests
        general_battery_tests(m, case)
        battery_prev_usage_tests(m, case)

        # Test that the previous usage is correctly calculated in the first operational
        # period of representative periods that are not the first
        @test all(
            value.(m[:bat_prev_use][stor, first(t_rp)]) ≈
                value.(m[:bat_prev_use][stor, first(t_rp_prev)]) -
                value.(m[:stor_charge_use][stor, first(t_rp_prev)]) *
                0.9 * duration(first(t_rp_prev)) +
                value.(m[:bat_use_rp][stor, t_rp_prev]) +
                value.(m[:stor_charge_use][stor, first(t_rp)]) * 0.9 * duration(first(t_rp))
            for t_inv ∈ 𝒯ᴵⁿᵛ for (t_rp_prev, t_rp) ∈ withprev(repr_periods(t_inv))
        if !isnothing(t_rp_prev))
    end

    @testset "RepresentativePeriods - Cycle limit" begin
        bat_life = CycleLife(900, 0.2, FixedProfile(5e4))
        m, case, modeltype = small_graph(supply_price, el_demand; ops, bat_life)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        stor, sink = get_nodes(case)[[2, 3]]

        # Run the standard tests
        general_battery_tests(m, case)
        battery_prev_usage_tests(m, case)

        # Test that the capacity limit is correctly enforced in the complete horizon
        # - constraints_usage_iterate:
        #   - Division by 50 to account for the installed storage capacity of the battery
        #   - Multiplication with 2 to account for the duration of the strategic period
        #   - The value of 900 correspondsd to the cycle numbers
        @test sum(value.(m[:bat_use_sp])) / 50 * 2 ≤ 900

        # Test that the capacity limit is correctly enforced in the individual operational
        # periods
        # - capacity_reduction and constraints_capacity:
        #   - The value of 50 corresponds to the installed storage capacity of the battery
        #   - The value of 0.8 corresponds to 1-the final degradation percentage
        #   - The value of 900 correspondsd to the cycle numbers
        @test all(
            value.(m[:stor_level][stor, t]) ≤
                50 - 0.2 * value.(m[:bat_prev_use][stor, t]) / 900
        for t ∈ 𝒯)
    end
end

@testset "ReserveBattery" begin
    reserve_down = ResourceCarrier("Reserve Down", 0.0)
    reserve_up = ResourceCarrier("Reserve Up", 0.0)

    function small_graph(
        supply_price,
        el_demand;
        res_down_demand = FixedProfile(10),
        res_up_demand = FixedProfile(10),
        ops = SimpleTimes(10, [6, 3, 6, 3, 6, 6, 3, 6, 3, 6]),
    )

        products = [Power, reserve_down, reserve_up, CO2]
        # Creation of the source and sink module as well as the arrays used for nodes and links
        source = RefSource(
            "power_source",
            FixedProfile(20),
            supply_price,
            FixedProfile(1),
            Dict(Power => 1),
        )
        battery = ReserveBattery{CyclicStrategic}(
            "battery",
            StorCap(FixedProfile(20)),
            StorCap(FixedProfile(50)),
            StorCap(FixedProfile(20)),
            Power,
            Dict(Power => 0.9),
            Dict(Power => 0.9),
            InfLife(),
            [reserve_up],
            [reserve_down],
        )
        sink = RefSink(
            "power_demand",
            el_demand,
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e3)),
            Dict(Power => 1),
        )
        reserve_down_sink = RefSink(
            "reserve_down",
            res_down_demand,
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(100)),
            Dict(reserve_down => 1),
        )
        reserve_up_sink = RefSink(
            "reserve_up",
            res_up_demand,
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(50)),
            Dict(reserve_up => 1),
        )

        nodes = [source, battery, sink, reserve_down_sink, reserve_up_sink]
        links = [
            Direct("source-sink", nodes[1], nodes[3])
            Direct("source-bat", nodes[1], nodes[2])
            Direct("bat-sink", nodes[2], nodes[3])
            Direct("bat-reserve_down_sink", nodes[2], nodes[4])
            Direct("bat-reserve_up_sink", nodes[2], nodes[5])
        ]

        # Creation of the time structure and the used global data
        op_per_strat = 8760.0
        T = TwoLevel(2, 2, ops; op_per_strat)
        modeltype = OperationalModel(
            Dict(CO2 => FixedProfile(10)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )

        # Input data structure
        case = Case(T, products, [nodes, links], [[get_nodes, get_links]])

        # Creation and solving of the model
        m = create_model(case, modeltype)
        set_optimizer(m, OPTIMIZER)
        optimize!(m)

        return m, case, modeltype
    end

    # Modelling of two days with typical demand and price profiles
    el_demand = OperationalProfile([16; 28; 20; 25; 18; 15; 25; 20; 28; 18])
    supply_price = OperationalProfile([30; 80; 60; 80; 40; 30; 80; 60; 80; 40])
    m, case, modeltype = small_graph(supply_price, el_demand)

    # Extract the data
    𝒯 = get_time_struct(case)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    stor = get_nodes(case)[2]

    # Run the standard tests
    general_battery_tests(m, case)

    # Test that the reserve equals the flow out
    # - EMB.constraints_flow_out(m, n::ReserveBattery, 𝒯::TimeStructure, modeltype::EnergyModel)
    @test all(
        value.(m[:flow_out][stor, t, reserve_down]) ≈
            value.(m[:bat_res_down][stor, t])
    for t ∈ 𝒯)
    @test all(
        value.(m[:flow_out][stor, t, reserve_up]) ≈
            value.(m[:bat_res_up][stor, t])
    for t ∈ 𝒯)

    # Test that the reserve is correctly bounded from above through both the charge/discharge
    # capacity and the level capacity
    # - EMB.constraints_capacity(m, n::ReserveBattery, 𝒯::TimeStructure, modeltype::EnergyModel)
    @test all(
        value.(m[:bat_res_down][stor, t]) ≤
            capacity(level(stor), t) - value.(m[:stor_level][stor, t]) + TEST_ATOL
    for t ∈ 𝒯)
    @test all(
        value.(m[:bat_res_down][stor, t]) ≤
            value.(m[:stor_discharge_use][stor, t]) - value.(m[:stor_charge_use][stor, t]) +
            capacity(charge(stor), t) + TEST_ATOL
    for t ∈ 𝒯)
    @test all(
        value.(m[:bat_res_up][stor, t]) ≤ value.(m[:stor_level][stor, t]) + TEST_ATOL
    for t ∈ 𝒯)
    @test all(
        value.(m[:bat_res_up][stor, t]) ≤
            value.(m[:stor_charge_use][stor, t]) - value.(m[:stor_discharge_use][stor, t]) +
            capacity(discharge(stor), t) + TEST_ATOL
    for t ∈ 𝒯)
end
