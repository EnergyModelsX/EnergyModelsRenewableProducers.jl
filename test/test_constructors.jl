@testset "Legacy constructors" begin

    # Used parameters
    rate_cap = FixedProfile(2.0)
    stor_cap = FixedProfile(40)

    level_init = StrategicProfile([20, 25, 30, 20])
    level_inflow = FixedProfile(10)
    level_min = StrategicProfile([0.1, 0.2, 0.05, 0.1])

    opex_var = FixedProfile(10)
    opex_var_pump = FixedProfile(10)
    opex_fixed = FixedProfile(10)

    stor_res = Power
    input = Dict(Power => 0.9)
    output = Dict(Power => 1)

    data = Data[]

    # Check that `Hydrostor` nodes are correctly constructed
    @testset "Hydrostor node wo data" begin
        hydro_old = HydroStor(
            "hydro",
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

        hydro_new = HydroStor{CyclicStrategic}(
            "hydro",
            StorCapOpexFixed(stor_cap, opex_fixed),
            StorCapOpexVar(rate_cap, opex_var),
            level_init,
            level_inflow,
            level_min,
            stor_res,
            input,
            output,
            Data[],
        )
        for field ∈ fieldnames(HydroStor{CyclicStrategic})
            @test getproperty(hydro_old, field) == getproperty(hydro_new, field)
        end
    end
    @testset "Hydrostor node with data" begin
        hydro_old = HydroStor(
            "hydro",
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
            data,
        )

        hydro_new = HydroStor{CyclicStrategic}(
            "hydro",
            StorCapOpexFixed(stor_cap, opex_fixed),
            StorCapOpexVar(rate_cap, opex_var),
            level_init,
            level_inflow,
            level_min,
            stor_res,
            input,
            output,
            data,
        )
        for field ∈ fieldnames(HydroStor{CyclicStrategic})
            @test getproperty(hydro_old, field) == getproperty(hydro_new, field)
        end
    end


    # Check that `PumpedHydroStor` nodes are correctly constructed
    @testset "PumpedHydroStor node wo data" begin
        hydro_old = PumpedHydroStor(
            "hydro",
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

        hydro_new = PumpedHydroStor{CyclicStrategic}(
            "hydro",
            StorCapOpexVar(rate_cap, opex_var_pump),
            StorCapOpexFixed(stor_cap, opex_fixed),
            StorCapOpexVar(rate_cap, opex_var),
            level_init,
            level_inflow,
            level_min,
            stor_res,
            input,
            output,
            Data[],
        )
        for field ∈ fieldnames(PumpedHydroStor{CyclicStrategic})
            @test getproperty(hydro_old, field) == getproperty(hydro_new, field)
        end
    end
    @testset "PumpedHydroStor node with data" begin
        hydro_old = PumpedHydroStor(
            "hydro",
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
            data,
        )

        hydro_new = PumpedHydroStor{CyclicStrategic}(
            "hydro",
            StorCapOpexVar(rate_cap, opex_var_pump),
            StorCapOpexFixed(stor_cap, opex_fixed),
            StorCapOpexVar(rate_cap, opex_var),
            level_init,
            level_inflow,
            level_min,
            stor_res,
            input,
            output,
            data,
        )
        for field ∈ fieldnames(PumpedHydroStor{CyclicStrategic})
            @test getproperty(hydro_old, field) == getproperty(hydro_new, field)
        end
    end
end

@testset "Simplified constructors" begin

    # Used parameters
    charge = StorCapOpex(FixedProfile(5), FixedProfile(1), FixedProfile(50))
    level = StorCapOpexFixed(FixedProfile(100), FixedProfile(10))
    discharge = StorCapOpexVar(FixedProfile(2), FixedProfile(1))

    level_init = StrategicProfile([20, 25, 30, 20])
    level_inflow = FixedProfile(10)
    level_min = StrategicProfile([0.1, 0.2, 0.05, 0.1])

    opex_var = FixedProfile(10)
    opex_var_pump = FixedProfile(10)
    opex_fixed = FixedProfile(10)

    stor_res = Power
    input = Dict(Power => 0.9)
    output = Dict(Power => 1)

    data = Data[]

    # Check that `Hydrostor` nodes are correctly constructed when using simplified
    # constructors
    @testset "Hydrostor node wo data" begin
        hydro_old = HydroStor{CyclicStrategic}(
            "hydro",
            level,
            discharge,
            level_init,
            level_inflow,
            level_min,
            stor_res,
            input,
            output,
        )

        hydro_new = HydroStor{CyclicStrategic}(
            "hydro",
            level,
            discharge,
            level_init,
            level_inflow,
            level_min,
            stor_res,
            input,
            output,
            data,
        )
        for field ∈ fieldnames(HydroStor{CyclicStrategic})
            @test getproperty(hydro_old, field) == getproperty(hydro_new, field)
        end
    end
    @testset "Hydrostor node wo input" begin
        hydro_old = HydroStor{CyclicStrategic}(
            "hydro",
            level,
            discharge,
            level_init,
            level_inflow,
            level_min,
            stor_res,
            output,
            data,
        )

        hydro_new = HydroStor{CyclicStrategic}(
            "hydro",
            level,
            discharge,
            level_init,
            level_inflow,
            level_min,
            stor_res,
            Dict{Resource,Real}(stor_res => 1),
            output,
            data,
        )
        for field ∈ fieldnames(HydroStor{CyclicStrategic})
            @test getproperty(hydro_old, field) == getproperty(hydro_new, field)
        end

    end
    @testset "Hydrostor node wo data and input" begin
        hydro_old = HydroStor{CyclicStrategic}(
            "hydro",
            level,
            discharge,
            level_init,
            level_inflow,
            level_min,
            stor_res,
            output,
        )

        hydro_new = HydroStor{CyclicStrategic}(
            "hydro",
            level,
            discharge,
            level_init,
            level_inflow,
            level_min,
            stor_res,
            Dict{Resource,Real}(stor_res => 1),
            output,
            Data[],
        )
        for field ∈ fieldnames(HydroStor{CyclicStrategic})
            @test getproperty(hydro_old, field) == getproperty(hydro_new, field)
        end

        # Test that an empty input results in a running model
        case, modeltype = small_graph()

        # Updating the nodes and the links
        push!(case[:nodes], hydro_new)
        link_from = EMB.Direct(41, case[:nodes][4], case[:nodes][1], EMB.Linear())
        push!(case[:links], link_from)
        link_to = EMB.Direct(14, case[:nodes][1], case[:nodes][4], EMB.Linear())
        push!(case[:links], link_to)

        # Run the model
        m = EMB.run_model(case, modeltype, OPTIMIZER)

        # Run of the general and node tests
        general_tests(m)
        general_node_tests(m, case, hydro_new)
    end

    # Check that `PumpedHydroStor` nodes are correctly constructed when using simplified
    # constructors
    @testset "PumpedHydroStor node wo data" begin
        hydro_old = PumpedHydroStor{CyclicStrategic}(
            "hydro",
            charge,
            level,
            discharge,
            level_init,
            level_inflow,
            level_min,
            stor_res,
            input,
            output,
        )

        hydro_new = PumpedHydroStor{CyclicStrategic}(
            "hydro",
            charge,
            level,
            discharge,
            level_init,
            level_inflow,
            level_min,
            stor_res,
            input,
            output,
            data,
        )
        for field ∈ fieldnames(HydroStor{CyclicStrategic})
            @test getproperty(hydro_old, field) == getproperty(hydro_new, field)
        end
    end
end
