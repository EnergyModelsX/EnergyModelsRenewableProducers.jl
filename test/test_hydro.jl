
function general_node_tests(m, case, n::EMRP.HydroStorage)

    # Extract time structure and storage node
    𝒯 = case[:T]
    p_stor = EMB.storage_resource(n)

    @testset "stor_level bounds" begin
        # The storage level has to be greater than the required minimum.
        @test sum(
            EMRP.level_min(n, t) * value.(m[:stor_level_inst][n, t]) <=
            round(value.(m[:stor_level][n, t]), digits = ROUND_DIGITS) for t ∈ 𝒯
        ) == length(𝒯)

        # The stor_level has to be less than stor_level_inst in all operational periods.
        @test sum(
            value.(m[:stor_level][n, t]) <= value.(m[:stor_level_inst][n, t]) for t ∈ 𝒯
        ) == length(𝒯)
        # TODO valing Storage node har negativ stor_level_inst et par steder.
        # TODO this is ok when inflow=1. When inflow=10 the stor_level gets too large. Why?
        #  - Do we need some other sink in the system? Not logical to be left with too much power.

        # Test that the Δ in the storage level is correctly calculated
        # - constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫)
        @test sum(
            value.(value.(m[:stor_level_Δ_op][n, t])) ≈
            EMRP.level_inflow(n, t) + inputs(n, p_stor) * value.(m[:flow_in][n, t, p_stor]) -
            value.(m[:stor_discharge_use][n, t]) - value.(m[:hydro_spill][n, t]) for t ∈ 𝒯,
            atol ∈ TEST_ATOL
        ) ≈ length(𝒯) atol = TEST_ATOL

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
        @test sum(value.(m[:stor_level_inst][n, t]) >= 0 for t ∈ 𝒯) == length(𝒯)

        # Check that stor_level_inst is set to cap.level.
        @test sum(value.(m[:stor_level_inst][n, t]) == capacity(level(n), t) for t ∈ 𝒯) == length(𝒯)
    end

    @testset "stor_discharge_use bounds" begin
        # Cannot produce more than what is stored in the reservoir.
        @test sum(
            value.(m[:stor_discharge_use][n, t]) <= value.(m[:stor_level][n, t]) for t ∈ 𝒯
        ) == length(𝒯)

        # Check that stor_discharge_use is bounded above by stor_discharge_inst.
        @test sum(
            round(value.(m[:stor_discharge_use][n, t]), digits = ROUND_DIGITS) <=
            value.(m[:stor_discharge_inst][n, t]) for t ∈ 𝒯
        ) == length(𝒯)
    end

    @testset "stor_discharge_inst" begin
        @test sum(value.(m[:stor_discharge_inst][n, t]) == capacity(discharge(n), t) for t ∈ 𝒯) == length(𝒯)
    end

    @testset "flow variables" begin
        # The flow_out corresponds to the production stor_discharge_use.
        @test sum(
            value.(m[:flow_out][n, t, p_stor]) ==
            value.(m[:stor_discharge_use][n, t]) * outputs(n, Power) for t ∈ 𝒯
        ) == length(𝒯)
    end
end

function check_node(nodetype::Type{<:EMRP.HydroStorage})

    function check_graph(
        hydro::Type{<:EMRP.HydroStorage};
        rate_cap = FixedProfile(2.0),
        stor_cap = FixedProfile(40),
        level_init = StrategicProfile([20, 25, 30, 20]),
        level_inflow = FixedProfile(10),
        level_min = StrategicProfile([0.1, 0.2, 0.05, 0.1]),
        opex_var = FixedProfile(10),
        opex_var_pump = FixedProfile(10),
        opex_fixed = FixedProfile(10),
        stor_res = Power,
        input = Dict(Power => 0.9),
        output = Dict(Power => 1),
        )

        if hydro <: HydroStor
            hydro = HydroStor(
                "-hydro",
                rate_cap,
                stor_cap,
                level_init,
                level_inflow,
                level_min,
                opex_var,
                opex_fixed,
                stor_res,
                input,
                output,
            )

        elseif hydro <: PumpedHydroStor
            hydro = HydroStor(
                "-hydro",
                rate_cap,
                stor_cap,
                level_init,
                level_inflow,
                level_min,
                opex_var,
                opex_var_pump,
                opex_fixed,
                stor_res,
                input,
                output,
            )
        end

        case, modeltype = small_graph()

        # Updating the nodes and the links
        push!(case[:nodes], hydro)
        link_from = EMB.Direct(41, case[:nodes][4], case[:nodes][1], EMB.Linear())
        push!(case[:links], link_from)
        link_to = EMB.Direct(14, case[:nodes][1], case[:nodes][4], EMB.Linear())
        push!(case[:links], link_to)

        # Run the model
        return EMB.run_model(case, modeltype, OPTIMIZER)
    end

    @testset "Checks" begin

        # Set the global to true to suppress the error message
        EMB.TEST_ENV = true

        # Test that a wrong capacity is caught by the checks.
        rate_cap = FixedProfile(-2.0)
        @test_throws AssertionError check_graph(HydroStor; rate_cap)
        stor_cap = FixedProfile(-40)
        @test_throws AssertionError check_graph(HydroStor; stor_cap)

        # Test that a wrong fixed OPEX is caught by the checks.
        opex_fixed = FixedProfile(-10)
        @test_throws AssertionError check_graph(HydroStor; opex_fixed)

        # Test that a wrong output dictionary is caught by the checks.
        output = Dict(Power => 1, CO2 => 0.5)
        @test_throws AssertionError check_graph(HydroStor; output)
        output = Dict(Power => 1.5)
        @test_throws AssertionError check_graph(HydroStor; output)
        output = Dict(Power => -1.0)
        @test_throws AssertionError check_graph(HydroStor; output)

        # Test that a wrong input dictionary is caught by the checks.
        input = Dict(Power => 1.5)
        @test_throws AssertionError check_graph(HydroStor; input)
        input = Dict(Power => -0.9)
        @test_throws AssertionError check_graph(HydroStor; input)

        # Test that a wrong initial level is caught by the checks.
        level_init = StrategicProfile([50, 25, 45, 20])
        @test_throws AssertionError check_graph(HydroStor; level_init)
        level_init = StrategicProfile([40, 25, 1, 20])
        level_min = FixedProfile(.5)
        @test_throws AssertionError check_graph(HydroStor; level_init, level_min)
        level_init = StrategicProfile([40, 25, -5, 20])
        @test_throws AssertionError check_graph(HydroStor; level_init)

        # Test that a wrong minimum level is caught by the checks.
        level_min = FixedProfile(-0.5)
        @test_throws AssertionError check_graph(HydroStor; level_min)
        level_min = FixedProfile(2)
        @test_throws AssertionError check_graph(HydroStor; level_min)

        # Set the global again to false
        EMB.TEST_ENV = false
    end

end

@testset "HydroStor - regulated hydro power plant" begin

    # Test that the fields of a HydroStor are correctly checked
    # - check_node(n::HydroStor, 𝒯, modeltype::EnergyModel)
    check_node(HydroStor)

    # Creation of the initial problem and the HydroStor node
    max_storage = FixedProfile(100)
    initial_reservoir = StrategicProfile([20, 25, 30, 20])
    min_level = StrategicProfile([0.1, 0.2, 0.05, 0.1])

    # Regular nice hydro storage node.
    hydro1 = HydroStor(
        "-hydro",
        FixedProfile(2.0),
        max_storage,
        initial_reservoir,
        FixedProfile(1),
        min_level,
        FixedProfile(10),
        FixedProfile(10),
        Power,
        Dict(Power => 0.9),
        Dict(Power => 1),
    )

    # Gives infeasible model without spill-variable (because without spill, the inflow is
    # much greater than what the Rate_cap can handle, given the Stor_cap of the storage).
    hydro2 = HydroStor(
        "-hydro",
        FixedProfile(2.0),
        FixedProfile(40),
        initial_reservoir,
        FixedProfile(10),
        min_level,
        FixedProfile(10),
        FixedProfile(10),
        Power,
        Dict(Power => 0.9),
        Dict(Power => 1),
    )
    for hydro ∈ [hydro1, hydro2]
        # Create the basic energy system model.
        case, modeltype = small_graph()

        # Updating the nodes and the links
        push!(case[:nodes], hydro)
        link_from = EMB.Direct(41, case[:nodes][4], case[:nodes][1], EMB.Linear())
        push!(case[:links], link_from)
        link_to = EMB.Direct(14, case[:nodes][1], case[:nodes][4], EMB.Linear())
        push!(case[:links], link_to)

        # Run the model
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extraction of the time structure
        𝒯 = case[:T]

        # Run of the general and node tests
        general_tests(m)
        general_node_tests(m, case, hydro)

        @testset "no pump" begin
            # No pump means no inflow.
            @test sum(
                value.(m[:flow_in][hydro, t, p]) == 0 for t ∈ 𝒯 for p ∈ inputs(hydro)
            ) == length(𝒯)
        end

        @testset "flow_in" begin
            # Check that the zero equality constraint is set on the flow_in variable
            # when the pump is not allowed. If this false, there might be errors in
            # the links to the node. The hydro node need one in and one out.
            logic_1 = sum(
                sum(
                    occursin("flow_in[n_-hydro,$t,Power] = 0", string(constraint)) for
                    constraint ∈ all_constraints(m, AffExpr, MOI.EqualTo{Float64})
                ) == 1 for t ∈ 𝒯
            ) == length(𝒯)
            logic_2 = sum(
                sum(
                    occursin("flow_in[n_-hydro,$t,Power] == 0", string(constraint)) for
                    constraint ∈ all_constraints(m, AffExpr, MOI.EqualTo{Float64})
                ) == 1 for t ∈ 𝒯
            ) == length(𝒯)
            @test logic_1 || logic_2
        end

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
        push!(case[:nodes], hydro1)
        link_from = EMB.Direct(41, case[:nodes][4], case[:nodes][1], EMB.Linear())
        push!(case[:links], link_from)
        link_to = EMB.Direct(14, case[:nodes][1], case[:nodes][4], EMB.Linear())
        push!(case[:links], link_to)

        # Run the model
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Extraction of the time structure
        𝒯 = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Run of the general and node tests
        general_tests(m)
        general_node_tests(m, case, hydro1)

        # All the tests following er for the function
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
end

@testset "PumpedHydroStor - regulated hydro storage with pumped storage" begin

    # Test that the fields of a HydroStor are correctly checked
    # - check_node(n::HydroStor, 𝒯, modeltype::EnergyModel)
    check_node(PumpedHydroStor)

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
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        Dict(Power => 1),
    )

    case, modeltype = small_graph(;source, sink)

    max_storage = FixedProfile(100)
    initial_reservoir = StrategicProfile([20, 25])
    min_level = StrategicProfile([0.1, 0.2])
    hydro = EMRP.PumpedHydroStor(
        "-hydro",
        FixedProfile(10.0),
        max_storage,
        initial_reservoir,
        FixedProfile(1),
        min_level,
        FixedProfile(0),
        FixedProfile(30),
        FixedProfile(10),
        Power,
        Dict(Power => 1),
        Dict(Power => 0.9),
    )

    # Updating the nodes and the links
    push!(case[:nodes], hydro)
    link_from = EMB.Direct(41, case[:nodes][4], case[:nodes][1], EMB.Linear())
    push!(case[:links], link_from)
    link_to = EMB.Direct(14, case[:nodes][1], case[:nodes][4], EMB.Linear())
    push!(case[:links], link_to)

    case[:T] = TwoLevel(2, 1, SimpleTimes(10, 1))

    # Run the model
    m = EMB.run_model(case, modeltype, OPTIMIZER; check_timeprofiles=false)

    # Extraction of the time structure
    𝒯 = case[:T]

    # Run of the general and node tests
    general_tests(m)
    general_node_tests(m, case, hydro)

    @testset "flow_in" begin
        # Check that the zero equality constraint is not set on the flow_in variable
        # when the pump is allowed. If this fails, there might be errors in the links
        # to the node. The hydro node need one in and one out.
        logic_1 = sum(
            sum(
                occursin("flow_in[n_-hydro,$t,Power] = 0", string(constraint)) for
                constraint ∈ all_constraints(m, AffExpr, MOI.EqualTo{Float64})
            ) == 0 for t ∈ 𝒯
        ) == length(𝒯)
        logic_2 = sum(
            sum(
                occursin("flow_in[n_-hydro,$t,Power] == 0", string(constraint)) for
                constraint ∈ all_constraints(m, AffExpr, MOI.EqualTo{Float64})
            ) == 0 for t ∈ 𝒯
        ) == length(𝒯)
        @test logic_1 || logic_2
    end

    @testset "deficit" begin
        if sum(value.(m[:sink_deficit][sink, t]) for t ∈ 𝒯) > 0
            # Check that the other source operates on its maximum if there is a deficit at the sink node,
            # since this should be used to fill the reservoir (if the reservoir is not full enough at the
            # beginning, and the inflow is too low).
            @test sum(
                value.(m[:cap_use][source, t]) == value.(m[:cap_inst][source, t]) for t ∈ 𝒯
            ) == length(𝒯)
        end
    end
end
