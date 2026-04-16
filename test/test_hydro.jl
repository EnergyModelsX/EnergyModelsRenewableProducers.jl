function gen_tests_hydro(m, case, n::EMRP.HydroStorage)

    # Extract time structure and storage node
    𝒯 = get_time_struct(case)
    p_stor = EMB.storage_resource(n)

    @testset "stor_level bounds" begin
        # The storage level has to be greater than the required minimum.
        @test all(
            EMRP.level_min(n, t) * value.(m[:stor_level_inst][n, t]) ≤
            round(value.(m[:stor_level][n, t]), digits = ROUND_DIGITS) for t ∈ 𝒯
        )

        # The stor_level has to be less than stor_level_inst in all operational periods.
        @test all(
            value.(m[:stor_level][n, t]) ≤ value.(m[:stor_level_inst][n, t]) for t ∈ 𝒯
        )
        # TODO valing Storage node har negativ stor_level_inst et par steder.
        # TODO this is ok when inflow=1. When inflow=10 the stor_level gets too large. Why?
        #  - Do we need some other sink in the system? Not logical to be left with too much power.

        # Test that the Δ in the storage level is correctly calculated
        # - constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫)
        @test all(
            value.(value.(m[:stor_level_Δ_op][n, t])) ≈
            EMRP.level_inflow(n, t) + inputs(n, p_stor) * value.(m[:flow_in][n, t, p_stor]) -
            value.(m[:stor_discharge_use][n, t]) - value.(m[:hydro_spill][n, t]) for t ∈ 𝒯
        )

        # At the first operation period of each investment period, the stor_level is set as
        # the initial reservoir level minus the production in that period.
        @test sum(
            value.(m[:stor_level][n, first(t_inv)]) ≈
            EMRP.level_init(n, t_inv) +
            duration(first(t_inv)) * (
                EMRP.level_inflow(n, first(t_inv)) +
                value.(m[:flow_in][n, first(t_inv), p_stor]) -
                value.(m[:stor_discharge_use][n, first(t_inv)]) -
                value.(m[:hydro_spill][n, first(t_inv)])
            ) for t_inv ∈ strategic_periods(𝒯)
        ) == length(strategic_periods(𝒯))

        # Check that stor_level is correct wrt. previous stor_level, inflow and stor_discharge_use.
        if 𝒯 isa TwoLevel{T,T,U} where {T,U<:SimpleTimes}
            non_first = 𝒯.len
        else
            non_first = length(repr_periods(𝒯))
        end
        @test sum(
            value.(m[:stor_level][n, t]) ≈
            value.(m[:stor_level][n, t_prev]) +
            duration(t) * (
                EMRP.level_inflow(n, t) +
                inputs(n, p_stor) * value.(m[:flow_in][n, t, p_stor]) -
                value.(m[:stor_discharge_use][n, t]) - value.(m[:hydro_spill][n, t])
            ) for t_inv ∈ strategic_periods(𝒯) for
            (t_prev, t) ∈ withprev(t_inv) if !isnothing(t_prev)
        ) == length(𝒯) - non_first
    end

    @testset "stor_level_inst bounds" begin
        # Assure that the stor_level_inst variable is non-negative.
        @test all(value.(m[:stor_level_inst][n, t]) ≥ 0 for t ∈ 𝒯)

        # Check that stor_level_inst is set to cap.level.
        @test all(value.(m[:stor_level_inst][n, t]) == capacity(level(n), t) for t ∈ 𝒯)
    end

    @testset "stor_discharge_use bounds" begin
        # Cannot produce more than what is stored in the reservoir.
        @test all(
            value.(m[:stor_discharge_use][n, t]) ≤ value.(m[:stor_level][n, t]) for t ∈ 𝒯
        )

        # Check that stor_discharge_use is bounded above by stor_discharge_inst.
        @test all(
            round(value.(m[:stor_discharge_use][n, t]), digits = ROUND_DIGITS) ≤
            value.(m[:stor_discharge_inst][n, t]) for t ∈ 𝒯
        )
    end

    @testset "stor_discharge_inst" begin
        @test all(value.(m[:stor_discharge_inst][n, t]) == capacity(discharge(n), t) for t ∈ 𝒯)
    end

    @testset "flow variables" begin
        # The flow_out corresponds to the production stor_discharge_use.
        @test all(
            value.(m[:flow_out][n, t, p_stor]) ==
            value.(m[:stor_discharge_use][n, t]) * outputs(n, Power) for t ∈ 𝒯
        )
    end
end

function emrh_support_test(n::EMRP.HydroStorage; case=nothing)

    # Create the case
    if isnothing(case)
        case, modeltype = small_graph()

        # Updating the nodes and the links
        𝒩 = get_nodes(case)
        ℒ = get_links(case)
        push!(𝒩, n)
        link_from = EMB.Direct(41, 𝒩[4], 𝒩[1], EMB.Linear())
        push!(ℒ, link_from)
        link_to = EMB.Direct(14, 𝒩[1], 𝒩[4], EMB.Linear())
        push!(ℒ, link_to)
    end

    # Create the receding horizon modeltype
    modeltype = RecHorOperationalModel(
        Dict(CO2 => FixedProfile(400)),
        Dict(CO2 => FixedProfile(0)),
        CO2,
    )

    # Run the model with the standard approach
    m = EMB.run_model(case, modeltype, OPTIMIZER)

    # Extract time structure and storage node
    𝒯 = get_time_struct(case)
    p_stor = EMB.storage_resource(n)

    @testset "stor_level bounds" begin
        # The storage level has to be greater than the required minimum.
        @test all(
            EMRP.level_min(n, t) * value.(m[:stor_level_inst][n, t]) ≤
            round(value.(m[:stor_level][n, t]), digits = ROUND_DIGITS) for t ∈ 𝒯
        )

        # The stor_level has to be less than stor_level_inst in all operational periods.
        @test all(
            value.(m[:stor_level][n, t]) ≤ value.(m[:stor_level_inst][n, t]) for t ∈ 𝒯
        )
        # TODO valing Storage node har negativ stor_level_inst et par steder.
        # TODO this is ok when inflow=1. When inflow=10 the stor_level gets too large. Why?
        #  - Do we need some other sink in the system? Not logical to be left with too much power.

        # Test that the Δ in the storage level is correctly calculated
        # - constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EMRH.RecHorEnergyModel)
        @test all(
            value.(value.(m[:stor_level_Δ_op][n, t])) ≈
            EMRP.level_inflow(n, t) + inputs(n, p_stor) * value.(m[:flow_in][n, t, p_stor]) -
            value.(m[:stor_discharge_use][n, t]) - value.(m[:hydro_spill][n, t]) for t ∈ 𝒯
        )

        # Test that the initial level is different compared to the specified one.
        # - constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EMRH.RecHorEnergyModel)
        @test all(
            value.(m[:stor_level][n, first(t_inv)]) ≉
            EMRP.level_init(n, t_inv) +
            duration(first(t_inv)) * (
                EMRP.level_inflow(n, first(t_inv)) +
                value.(m[:flow_in][n, first(t_inv), p_stor]) -
                value.(m[:stor_discharge_use][n, first(t_inv)]) -
                value.(m[:hydro_spill][n, first(t_inv)])
            ) for t_inv ∈ strategic_periods(𝒯)
        )

        # Check that stor_level is correct wrt. previous stor_level, inflow and stor_discharge_use.
        if 𝒯 isa TwoLevel{T,T,U} where {T,U<:SimpleTimes}
            non_first = 𝒯.len
        else
            non_first = length(repr_periods(𝒯))
        end
        @test sum(
            value.(m[:stor_level][n, t]) ≈
            value.(m[:stor_level][n, t_prev]) +
            duration(t) * (
                EMRP.level_inflow(n, t) +
                inputs(n, p_stor) * value.(m[:flow_in][n, t, p_stor]) -
                value.(m[:stor_discharge_use][n, t]) - value.(m[:hydro_spill][n, t])
            ) for t_inv ∈ strategic_periods(𝒯) for
            (t_prev, t) ∈ withprev(t_inv) if !isnothing(t_prev)
        ) == length(𝒯) - non_first
    end

    @testset "stor_level_inst bounds" begin
        # Assure that the stor_level_inst variable is non-negative.
        @test all(value.(m[:stor_level_inst][n, t]) ≥ 0 for t ∈ 𝒯)

        # Check that stor_level_inst is set to cap.level.
        @test all(value.(m[:stor_level_inst][n, t]) == capacity(level(n), t) for t ∈ 𝒯)
    end

    @testset "stor_discharge_use bounds" begin
        # Cannot produce more than what is stored in the reservoir.
        @test all(
            value.(m[:stor_discharge_use][n, t]) ≤ value.(m[:stor_level][n, t]) for t ∈ 𝒯
        )

        # Check that stor_discharge_use is bounded above by stor_discharge_inst.
        @test all(
            round(value.(m[:stor_discharge_use][n, t]), digits = ROUND_DIGITS) ≤
            value.(m[:stor_discharge_inst][n, t]) for t ∈ 𝒯
        )
    end

    @testset "stor_discharge_inst" begin
        @test all(value.(m[:stor_discharge_inst][n, t]) == capacity(discharge(n), t) for t ∈ 𝒯)
    end

    @testset "flow variables" begin
        # The flow_out corresponds to the production stor_discharge_use.
        @test all(
            value.(m[:flow_out][n, t, p_stor]) ==
            value.(m[:stor_discharge_use][n, t]) * outputs(n, Power) for t ∈ 𝒯
        )
    end
end

@testset "HydroStor - regulated hydro power plant" begin
    # Creation of the initial problem and the HydroStor node
    max_storage = FixedProfile(100)
    initial_reservoir = StrategicProfile([20, 25, 30, 20])
    min_level = StrategicProfile([0.1, 0.2, 0.05, 0.1])

    # Regular nice hydro storage node.
    hydro1 = HydroStor{CyclicStrategic}(
        "hydro",
        StorCapOpexFixed(max_storage, FixedProfile(10)),
        StorCapOpexVar(FixedProfile(2.0), FixedProfile(10)),
        initial_reservoir,
        FixedProfile(1),
        min_level,
        Power,
        Dict(Power => 0.9),
        Dict(Power => 1),
    )

    # Gives infeasible model without spill-variable (because without spill, the inflow is
    # much greater than what the Rate_cap can handle, given the Stor_cap of the storage).
    hydro2 = HydroStor{CyclicStrategic}(
        "hydro",
        StorCapOpexFixed(FixedProfile(40), FixedProfile(10)),
        StorCapOpexVar(FixedProfile(2.0), FixedProfile(10)),
        initial_reservoir,
        FixedProfile(10),
        min_level,
        Power,
        Dict(Power => 0.9),
        Dict(Power => 1),
    )
    for hydro ∈ [hydro1, hydro2]
        # Create the basic energy system model.
        case, modeltype = small_graph()

        # Updating the nodes and the links
        𝒩 = get_nodes(case)
        ℒ = get_links(case)
        push!(𝒩, hydro)
        link_from = EMB.Direct(41, 𝒩[4], 𝒩[1], EMB.Linear())
        push!(ℒ, link_from)
        link_to = EMB.Direct(14, 𝒩[1], 𝒩[4], EMB.Linear())
        push!(ℒ, link_to)
        # Run the model
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extraction of the time structure
        𝒯 = get_time_struct(case)

        # Run of the general and node tests
        general_tests(m)
        gen_tests_hydro(m, case, hydro)

        # Check that the input flow is fixed to 0 for Power
        @test all(is_fixed(m[:flow_in][hydro, t, Power]) for t ∈ 𝒯)

        if hydro == hydro2
            # hydro2 should lead to spillage.
            @test sum(value.(m[:hydro_spill][hydro, t]) for t ∈ 𝒯) > 0
        end
    end

    @testset "representative periods" begin
        # Declare the representative periods
        op_1 = SimpleTimes(12, 1)
        op_2 = SimpleTimes(12, 1)
        ops = RepresentativePeriods(2, 48, [0.5, 0.5], [op_1, op_2])

        n = hydro1

        # Create the basic energy system model.
        case, modeltype = small_graph(ops = ops)

        # Updating the nodes and the links
        𝒩 = get_nodes(case)
        ℒ = get_links(case)

        push!(𝒩, hydro1)
        link_from = EMB.Direct(41, 𝒩[4], 𝒩[1], EMB.Linear())
        push!(ℒ, link_from)
        link_to = EMB.Direct(14, 𝒩[1], 𝒩[4], EMB.Linear())
        push!(ℒ, link_to)

        # Run the model
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extraction of the time structure
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Run of the general and node tests
        general_tests(m)
        gen_tests_hydro(m, case, hydro1)

        # Test the objective value
        @test objective_value(m) ≈ -116160.0

        # All the tests following are for the function
        # - constraints_level(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EnergyModel)
        for t_inv ∈ 𝒯ᴵⁿᵛ
            𝒯ʳᵖ = repr_periods(t_inv)
            for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ), (t_prev, t) ∈ withprev(t_rp)
                if isnothing(t_rp_prev) && isnothing(t_prev)
                    # Test for the correct accounting in the first operational period of the
                    # first representative period of a strategic period
                    t_rp_last = last(𝒯ʳᵖ)
                    Δlevel_rp = sum(
                        value.(m[:stor_level_Δ_op][n, t]) *
                        multiple_strat(t_inv, t) *
                        duration(t) for t ∈ t_rp_last
                    )
                    @test value.(m[:stor_level][n, t]) ≈
                          value.(m[:stor_level][n, first(t_rp_last)]) -
                          value.(m[:stor_level_Δ_op][n, first(t_rp_last)]) *
                          duration(first(t_rp_last)) +
                          Δlevel_rp +
                          value.(m[:stor_level_Δ_op][n, t]) * duration(t) atol = TEST_ATOL

                    @test value.(m[:stor_level][n, t]) -
                          value.(m[:stor_level_Δ_op][n, t]) * duration(t) ≥ -TEST_ATOL

                    @test value.(m[:stor_level][n, t]) -
                          value.(m[:stor_level_Δ_op][n, t]) * duration(t) ≤
                          value.(m[:stor_level_inst][n, t]) + TEST_ATOL

                elseif isnothing(t_prev)
                    # Test for the correct accounting in the first operational period of the
                    # other representative periods of a strategic period
                    Δlevel_rp = sum(
                        value.(m[:stor_level_Δ_op][n, t]) *
                        multiple_strat(t_inv, t) *
                        duration(t) for t ∈ t_rp_prev
                    )
                    @test value.(m[:stor_level][n, t]) ≈
                          value.(m[:stor_level][n, first(t_rp_prev)]) -
                          value.(m[:stor_level_Δ_op][n, first(t_rp_prev)]) *
                          duration(first(t_rp_prev)) +
                          Δlevel_rp +
                          value.(m[:stor_level_Δ_op][n, t]) * duration(t) atol = TEST_ATOL

                    @test value.(m[:stor_level][n, t]) -
                          value.(m[:stor_level_Δ_op][n, t]) * duration(t) ≥ -TEST_ATOL

                    @test value.(m[:stor_level][n, t]) -
                          value.(m[:stor_level_Δ_op][n, t]) * duration(t) ≤
                          value.(m[:stor_level_inst][n, t]) + TEST_ATOL
                end
            end
        end
    end

    @testset "EMRH support" begin
        emrh_support_test(hydro1)
    end
end

@testset "PumpedHydroStor - regulated hydro storage with pumped storage" begin
    # Creation of the initial problem and the PumpedHydroStor node with a pump.
    products = [Power, CO2]
    source = EMB.RefSource(
        "-source",
        OperationalProfile([10, 10, 10, 10, 10, 0, 0, 0, 0, 0]),
        FixedProfile(10),
        FixedProfile(10),
        Dict(Power => 1),
    )

    sink = EMB.RefSink(
        "-sink",
        FixedProfile(7),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e2)),
        Dict(Power => 1),
    )

    case, modeltype = small_graph(;source, sink)

    max_storage = FixedProfile(100)
    initial_reservoir = StrategicProfile([20, 25])
    min_level = StrategicProfile([0.1, 0.2])
    hydro = PumpedHydroStor{CyclicStrategic}(
        "-hydro",
        StorCapOpexVar(FixedProfile(10.0), FixedProfile(30)),
        StorCapOpexFixed(max_storage, FixedProfile(10)),
        StorCapOpexVar(FixedProfile(10.0), FixedProfile(5)),
        initial_reservoir,
        FixedProfile(1),
        min_level,
        Power,
        Dict(Power => 1),
        Dict(Power => 0.9),
    )
    # Updating the nodes and the links
    𝒫 = get_products(case)
    𝒩 = get_nodes(case)
    ℒ = get_links(case)

    push!(𝒩, hydro)
    link_from = EMB.Direct(41, 𝒩[4], 𝒩[1], EMB.Linear())
    push!(ℒ, link_from)
    link_to = EMB.Direct(14, 𝒩[1], 𝒩[4], EMB.Linear())
    push!(ℒ, link_to)

    𝒯 = TwoLevel(2, 1, SimpleTimes(10, 1); op_per_strat=10)
    case = Case(𝒯, 𝒫, [𝒩, ℒ], [[get_nodes, get_links]])

    # Run the model
    modeltype = OperationalModel(
        Dict(CO2 => StrategicProfile([450, 400])),
        Dict(CO2 => FixedProfile(0)),
        CO2,
    )
    m = EMB.run_model(case, modeltype, OPTIMIZER)

    # Extraction of the time structure
    𝒯 = get_time_struct(case)

    # Run of the general and node tests
    general_tests(m)
    gen_tests_hydro(m, case, hydro)

    # Test the objective value
    # -25 in v0.6 compared to 0.5 as opex_var now via stor_discharge_use instead of flow_out
    @test objective_value(m) ≈ -6850.0

    # Check that the input flow is not fixed to 0 for Power
    @test all(!is_fixed(m[:flow_in][hydro, t, Power]) for t ∈ 𝒯)

    @testset "deficit" begin
        if sum(value.(m[:sink_deficit][sink, t]) for t ∈ 𝒯) > 0
            # Check that the other source operates on its maximum if there is a deficit at the sink node,
            # since this should be used to fill the reservoir (if the reservoir is not full enough at the
            # beginning, and the inflow is too low).
            @test all(
                value.(m[:cap_use][source, t]) == value.(m[:cap_inst][source, t]) for t ∈ 𝒯
            )
        end
    end

    @testset "EMRH support" begin
        emrh_support_test(hydro; case)
    end
end
