function general_battery_tests(m, case)
    # Extract the data
    𝒯 = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒩 = case[:nodes]
    stor = 𝒩[2]

    # Test that the level balance is correct for standard periods (6 times)
    @test sum(
        sum(
            value.(m[:stor_level][stor, t]) ≈
            value.(m[:stor_level][stor, t_prev]) +
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) for
            (t_prev, t) ∈ withprev(t_inv) if !isnothing(t_prev)
        ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol ∈ TEST_ATOL
    ) ≈ length(𝒯) - 2 atol = TEST_ATOL

    # Test that the level balance is correct in the first period (2 times)
    @test sum(
        sum(
            value.(m[:stor_level][stor, t]) ≈
            value.(m[:stor_level][stor, last(t_inv)]) +
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) for
            (t_prev, t) ∈ withprev(t_inv) if isnothing(t_prev)
        ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol ∈ TEST_ATOL
    ) ≈ 2 atol = TEST_ATOL

    # Test that the changes in the storage level is correctly calculated
    @test all(
        value.(m[:stor_level_Δ_op][stor, t]) ≈
            value.(m[:stor_charge_use][stor, t])*0.9 -
            value.(m[:stor_discharge_use][stor, t])/0.9
    for t ∈ 𝒯)

    # Test that both the outlet flow is correctly calculated.
    # The inlet flow is based on the standard approach
    @test all(
        value.(m[:flow_out][stor, t, Power]) ≈
            value.(m[:stor_discharge_use][stor, t])
    for t ∈ 𝒯)
end

@testset "ReserveBattery" begin
    reserve_down = ResourceCarrier("Reserve Down", 0.0)
    reserve_up = ResourceCarrier("Reserve Up", 0.0)

    function small_graph(
        supply_price,
        el_demand;
        res_down_demand = FixedProfile(10),
        res_up_demand = FixedProfile(10),
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
        T = TwoLevel(2, 1, SimpleTimes(10, [6, 3, 6, 3, 6, 6, 3, 6, 3, 6]))
        modeltype = OperationalModel(
            Dict(CO2 => FixedProfile(10)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )

        # Creation of the case dictionary
        case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

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
    𝒯 = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒩 = case[:nodes]
    stor = 𝒩[2]

    # Run the standard tests
    general_tests(m)
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
        value.(m[:bat_res_down][stor, t]) ≤ value.(m[:stor_level][stor, t]) + TEST_ATOL
    for t ∈ 𝒯)
    @test all(
        value.(m[:bat_res_down][stor, t]) ≤
            value.(m[:stor_discharge_use][stor, t]) - value.(m[:stor_charge_use][stor, t]) +
            capacity(charge(stor), t) + TEST_ATOL
    for t ∈ 𝒯)
    @test all(
        value.(m[:bat_res_up][stor, t]) ≤
            capacity(level(stor), t) - value.(m[:stor_level][stor, t]) + TEST_ATOL
    for t ∈ 𝒯)
    @test all(
        value.(m[:bat_res_up][stor, t]) ≤
            value.(m[:stor_charge_use][stor, t]) - value.(m[:stor_discharge_use][stor, t]) +
            capacity(discharge(stor), t) + TEST_ATOL
    for t ∈ 𝒯)
end
