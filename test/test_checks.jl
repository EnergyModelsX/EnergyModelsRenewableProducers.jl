
# Set the global to true to suppress the error message
EMB.TEST_ENV = true

# Test that the fields of a NonDisRES are correctly checked
# - check_node(n::NonDisRES, 𝒯, modeltype::EnergyModel)
@testset "NonDisRES" begin
    # Function for setting up the system for testing a `NonDisRES` node
    function check_graph(;
        cap = FixedProfile(20),
        profile = FixedProfile(0.5),
        opex_fixed = FixedProfile(1),
        output = Dict(Power => 1.0),
    )

        products = [Power, CO2]
        # Creation of the source and sink module as well as the arrays used for nodes and links
        source = NonDisRES(
            "wind",
            cap,
            profile,
            FixedProfile(10),
            opex_fixed,
            output,
        )
        sink = RefSink(
            "power_demand",
            FixedProfile(10),
            Dict(:surplus => FixedProfile(0), :deficit => StrategicProfile([1e3,2e2])),
            Dict(Power => 1),
        )

        nodes = [source, sink]
        links = [
            Direct("source-sink", nodes[1], nodes[2])
        ]

        # Creation of the time structure and the used global data
        op_per_strat = 8760.0
        T = TwoLevel(2, 2, SimpleTimes(10,1); op_per_strat)
        modeltype = OperationalModel(
            Dict(CO2 => FixedProfile(10)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )

        # Creation of the case dictionary
        case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

        return create_model(case, modeltype), case, modeltype
    end

    # Test that a wrong capacity is caught by the checks
    @test_throws AssertionError check_graph(; cap=FixedProfile(-25))

    # Test that a wrong profile is caught by the checks
    @test_throws AssertionError check_graph(; profile=FixedProfile(-0.5))
    @test_throws AssertionError check_graph(; profile=FixedProfile(1.5))

    # Test that a wrong fixed OPEX is caught by the checks
    @test_throws AssertionError check_graph(; opex_fixed=FixedProfile(-5))

    # Test that a wrong output dictionary is caught
    @test_throws AssertionError check_graph(; output=Dict(Power => -0.9))
end

# Test that the fields of a `HydroStorage` are correctly checked
# - EMB.check_node(n::HydroStorage, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
@testset "HydroStor and PumpedHydroStor" begin

    # Function for setting up the system for testing an `PumpedHydroStorage` node
    function check_graph(;
        type = PumpedHydroStor,
        charge_cap = FixedProfile(20),
        charge_opex = FixedProfile(1),
        level_cap = FixedProfile(50),
        level_opex = FixedProfile(1),
        discharge_cap = FixedProfile(20),
        discharge_opex = FixedProfile(1),
        level_init = StrategicProfile([20, 25, 30, 20]),
        level_inflow = FixedProfile(10),
        level_min = StrategicProfile([0.1, 0.2, 0.05, 0.1]),
        input = Dict(Power => 0.9),
        output = Dict(Power => 0.9),
    )

        products = [Power, CO2]
        # Creation of the source and sink module as well as the arrays used for nodes and links
        source = RefSource(
            "power_source",
            FixedProfile(20),
            FixedProfile(50),
            FixedProfile(1),
            Dict(Power => 1),
        )
        if type <: PumpedHydroStor
            hydro = PumpedHydroStor{CyclicRepresentative}(
                "hydro",
                StorCapOpexFixed(charge_cap, charge_opex),
                StorCapOpexFixed(level_cap, level_opex),
                StorCapOpexFixed(discharge_cap, discharge_opex),
                level_init,
                level_inflow,
                level_min,
                Power,
                input,
                output,
            )
        else
            hydro = HydroStor{CyclicRepresentative}(
                "hydro",
                StorCapOpexFixed(level_cap, level_opex),
                StorCapOpexFixed(discharge_cap, discharge_opex),
                level_init,
                level_inflow,
                level_min,
                Power,
                input,
                output,
            )
        end
        sink = RefSink(
            "power_demand",
            FixedProfile(10),
            Dict(:surplus => FixedProfile(0), :deficit => StrategicProfile([1e3,2e2])),
            Dict(Power => 1),
        )

        nodes = [source, hydro, sink]
        links = [
            Direct("source-sink", nodes[1], nodes[3])
            Direct("source-hydro", nodes[1], nodes[2])
            Direct("bat-sink", nodes[2], nodes[3])
        ]

        # Creation of the time structure and the used global data
        op_per_strat = 8760.0
        T = TwoLevel(2, 2, SimpleTimes(24,1); op_per_strat)
        modeltype = OperationalModel(
            Dict(CO2 => FixedProfile(10)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )

        # Creation of the case dictionary
        case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

        return create_model(case, modeltype), case, modeltype
    end

    # Test that a wrong capacity is caught by the checks
    @test_throws AssertionError check_graph(; charge_cap=FixedProfile(-25))
    @test_throws AssertionError check_graph(; level_cap=FixedProfile(-25))
    @test_throws AssertionError check_graph(; discharge_cap=FixedProfile(-25))

    # Test that a wrong fixed OPEX is caught by the checks
    @test_throws AssertionError check_graph(; charge_opex=FixedProfile(-5))
    @test_throws AssertionError check_graph(; charge_opex=OperationalProfile([10]))
    @test_throws AssertionError check_graph(; level_opex=FixedProfile(-5))
    @test_throws AssertionError check_graph(; level_opex=OperationalProfile([10]))
    @test_throws AssertionError check_graph(; discharge_opex=FixedProfile(-5))
    @test_throws AssertionError check_graph(; discharge_opex=OperationalProfile([10]))

    # Test that a wrong input and output dictionaries are caught
    @test_throws AssertionError check_graph(; input=Dict(Power => 1.9))
    @test_throws AssertionError check_graph(; input=Dict(Power => -0.9))
    @test_throws AssertionError check_graph(; output=Dict(Power => 1.9))
    @test_throws AssertionError check_graph(; output=Dict(Power => -0.9))
    @test_throws AssertionError check_graph(; output=Dict(Power => 1.0, CO2 => 0.5))

    # Test that a wrong initial level is caught by the checks.
    level_init = StrategicProfile([50, 25, 45, 20])
    @test_throws AssertionError check_graph(; level_init)
    level_init = StrategicProfile([40, 25, 1, 20])
    level_min = FixedProfile(.5)
    @test_throws AssertionError check_graph(; level_init, level_min)
    level_init = StrategicProfile([40, 25, -5, 20])
    @test_throws AssertionError check_graph(; level_init)

    # Test that a wrong minimum level is caught by the checks.
    @test_throws AssertionError check_graph(; level_min=FixedProfile(-0.5))
    @test_throws AssertionError check_graph(; level_min=FixedProfile(2))

    # Test that the correct function is also called for HydroStor
    type = HydroStor{CyclicRepresentative}
    level_min = FixedProfile(-0.5)
    @test_throws AssertionError check_graph(; type, level_min)
end

# Test that the fields of a `AbstractBattery` are correctly checked
# - EMB.check_node(n::AbstractBattery, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
# - check_battery_life(n::AbstractBattery, bat_life::CycleLife, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
@testset "AbstractBattery" begin

    # Function for setting up the system for testing an `AbstractBattery` node
    function check_graph(;
        charge_cap = FixedProfile(20),
        charge_opex = FixedProfile(1),
        level_cap = FixedProfile(50),
        level_opex = FixedProfile(1),
        discharge_cap = FixedProfile(20),
        discharge_opex = FixedProfile(1),
        input = Dict(Power => 0.9),
        output = Dict(Power => 0.9),
        cycles = 900,
        degradation = 0.2,
        stack_cost = FixedProfile(100),
    )

        products = [Power, CO2]
        # Creation of the source and sink module as well as the arrays used for nodes and links
        source = RefSource(
            "power_source",
            FixedProfile(20),
            FixedProfile(50),
            FixedProfile(1),
            Dict(Power => 1),
        )
        battery = Battery{CyclicRepresentative}(
            "battery",
            StorCapOpexFixed(charge_cap, charge_opex),
            StorCapOpexFixed(level_cap, level_opex),
            StorCapOpexFixed(discharge_cap, discharge_opex),
            Power,
            input,
            output,
            CycleLife(
                cycles,
                degradation,
                stack_cost
            ),
        )
        sink = RefSink(
            "power_demand",
            FixedProfile(10),
            Dict(:surplus => FixedProfile(0), :deficit => StrategicProfile([1e3,2e2])),
            Dict(Power => 1),
        )

        nodes = [source, battery, sink]
        links = [
            Direct("source-sink", nodes[1], nodes[3])
            Direct("source-bat", nodes[1], nodes[2])
            Direct("bat-sink", nodes[2], nodes[3])
        ]

        # Creation of the time structure and the used global data
        op_per_strat = 8760.0
        T = TwoLevel(2, 2, SimpleTimes(10,1); op_per_strat)
        modeltype = OperationalModel(
            Dict(CO2 => FixedProfile(10)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )

        # Creation of the case dictionary
        case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

        return create_model(case, modeltype), case, modeltype
    end

    # Test that a wrong capacity is caught by the checks
    @test_throws AssertionError check_graph(; charge_cap=FixedProfile(-25))
    @test_throws AssertionError check_graph(; level_cap=FixedProfile(-25))
    @test_throws AssertionError check_graph(; discharge_cap=FixedProfile(-25))

    # Test that a wrong fixed OPEX is caught by the checks
    @test_throws AssertionError check_graph(; charge_opex=FixedProfile(-5))
    @test_throws AssertionError check_graph(; charge_opex=OperationalProfile([10]))
    @test_throws AssertionError check_graph(; level_opex=FixedProfile(-5))
    @test_throws AssertionError check_graph(; level_opex=OperationalProfile([10]))
    @test_throws AssertionError check_graph(; discharge_opex=FixedProfile(-5))
    @test_throws AssertionError check_graph(; discharge_opex=OperationalProfile([10]))

    # Test that a wrong input and output dictionaries are caught
    @test_throws AssertionError check_graph(; input=Dict(Power => 1.9))
    @test_throws AssertionError check_graph(; input=Dict(Power => -0.9))
    @test_throws AssertionError check_graph(; output=Dict(Power => 1.9))
    @test_throws AssertionError check_graph(; output=Dict(Power => -0.9))

    # Test that a wrong battery life is caught
    @test_throws AssertionError check_graph(; cycles=-10)
    @test_throws AssertionError check_graph(; degradation=10)
    @test_throws AssertionError check_graph(; degradation=-10)
    @test_throws AssertionError check_graph(; stack_cost=FixedProfile(-5))
    @test_throws AssertionError check_graph(; stack_cost=OperationalProfile([10]))

end

# Test that the fields of a `ReserveBattery` are correctly checked
# - EMB.check_node(n::ReserveBattery, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
# - check_battery_life(n::AbstractBattery, bat_life::CycleLife, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
@testset "ReserveBattery" begin

    # Add the reserve resources
    res_down = ResourceCarrier("Reserve Down", 0.0)
    res_up = ResourceCarrier("Reserve Up", 0.0)

    # Function for setting up the system for testing a `ReserveBattery` node
    function check_graph(;
        charge_cap = FixedProfile(20),
        charge_opex = FixedProfile(1),
        level_cap = FixedProfile(50),
        level_opex = FixedProfile(1),
        discharge_cap = FixedProfile(20),
        discharge_opex = FixedProfile(1),
        input = Dict(Power => 0.9),
        output = Dict(Power => 0.9),
        cycles = 900,
        degradation = 0.2,
        stack_cost = FixedProfile(100),
    )

        products = [Power, CO2, res_up, res_down]
        # Creation of the source and sink module as well as the arrays used for nodes and links
        source = RefSource(
            "power_source",
            FixedProfile(20),
            FixedProfile(50),
            FixedProfile(1),
            Dict(Power => 1),
        )
        battery = ReserveBattery{CyclicRepresentative}(
            "battery",
            StorCapOpexFixed(charge_cap, charge_opex),
            StorCapOpexFixed(level_cap, level_opex),
            StorCapOpexFixed(discharge_cap, discharge_opex),
            Power,
            input,
            output,
            CycleLife(
                cycles,
                degradation,
                stack_cost
            ),
            [res_up],
            [res_down],
        )
        sink = RefSink(
            "power_demand",
            FixedProfile(10),
            Dict(:surplus => FixedProfile(0), :deficit => StrategicProfile([1e3,2e2])),
            Dict(Power => 1),
        )

        nodes = [source, battery, sink]
        links = [
            Direct("source-sink", nodes[1], nodes[3])
            Direct("source-bat", nodes[1], nodes[2])
            Direct("bat-sink", nodes[2], nodes[3])
        ]

        # Creation of the time structure and the used global data
        op_per_strat = 8760.0
        T = TwoLevel(2, 2, SimpleTimes(10,1); op_per_strat)
        modeltype = OperationalModel(
            Dict(CO2 => FixedProfile(10)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )

        # Creation of the case dictionary
        case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

        return create_model(case, modeltype), case, modeltype
    end

    # Test that a wrong capacity is caught by the checks
    @test_throws AssertionError check_graph(; charge_cap=FixedProfile(-25))
    @test_throws AssertionError check_graph(; level_cap=FixedProfile(-25))
    @test_throws AssertionError check_graph(; discharge_cap=FixedProfile(-25))

    # Test that a wrong fixed OPEX is caught by the checks
    @test_throws AssertionError check_graph(; charge_opex=FixedProfile(-5))
    @test_throws AssertionError check_graph(; charge_opex=OperationalProfile([10]))
    @test_throws AssertionError check_graph(; level_opex=FixedProfile(-5))
    @test_throws AssertionError check_graph(; level_opex=OperationalProfile([10]))
    @test_throws AssertionError check_graph(; discharge_opex=FixedProfile(-5))
    @test_throws AssertionError check_graph(; discharge_opex=OperationalProfile([10]))

    # Test that a wrong input and output dictionaries are caught
    @test_throws AssertionError check_graph(; input=Dict(Power => 1.9))
    @test_throws AssertionError check_graph(; input=Dict(Power => -0.9))
    @test_throws AssertionError check_graph(; output=Dict(Power => 1.9))
    @test_throws AssertionError check_graph(; output=Dict(Power => -0.9))

    # Test that a wrong battery life is caught
    @test_throws AssertionError check_graph(; cycles=-10)
    @test_throws AssertionError check_graph(; degradation=10)
    @test_throws AssertionError check_graph(; degradation=-10)
    @test_throws AssertionError check_graph(; stack_cost=FixedProfile(-5))
    @test_throws AssertionError check_graph(; stack_cost=OperationalProfile([10]))

    # Test that inclusion of reserves in the fields input or output is caught
    @test_throws AssertionError check_graph(; input=Dict(Power => 1.9, res_up => 1))
    @test_throws AssertionError check_graph(; output=Dict(Power => 1.9, res_up => 1))
    @test_throws AssertionError check_graph(; input=Dict(Power => 1.9, res_down => 1))
    @test_throws AssertionError check_graph(; output=Dict(Power => 1.9, res_down => 1))
end

# Set the global again to false
EMB.TEST_ENV = false
