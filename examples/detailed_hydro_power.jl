using Pkg
# Activate the local environment including EnergyModelsRenewableProducers, HiGHS, PrettyTables
Pkg.activate(@__DIR__)
# Use dev version if run as part of tests
haskey(ENV, "EMX_TEST") && Pkg.develop(path=joinpath(@__DIR__,".."))
# Install the dependencies.
Pkg.instantiate()

# Import the required packages
using EnergyModelsBase
using EnergyModelsRenewableProducers
using HiGHS
using JuMP
using PrettyTables
using TimeStruct

const EMB = EnergyModelsBase

"""
    generate_detailed_hydropower()

Generate the data for an example consisting of cascaded hydropower system as illustrated in
the figure in the documentation
(https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/nodes/det_hydropower/description.html#nodes-det_hydro_power-phil/).
The `RefSource` is connected to the upper `HydroReservoir` to ensure the reservoir always
has at least one input.
The upper and lower `HydroReservoir` are connected through a `HydroGenerator`, a
`HydroPump`, and a `HydroGate`.
The lower `HydroReservoir` and the `RefSink` representing the ocean are connected through a
`HydroGenerator`.
It is in this example possible to both sell and buy from an electricity market

This examples shows the approach of designing a cascaded hydropower system with the different
nodes. The `HydroGate` is not used as the inflow is not large enough. to justify its application.
The `HydroPump` is used within the time periods in which electricity is cheap
"""
function generate_detailed_hydropower()
    @info "Generate case data - Detailed hydropower example"

    # Define the different resources and their emission intensity in tCO2/MWh
    # CO2 has to be defined, even if not used, as it is required for the `EnergyModel` type
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    Water = ResourceCarrier("Water", 0.0)
    products = [CO2, Power, Water]

    # Variables for the individual entries of the time structure
    op_duration = [1, 1, 2, 3] .* 24 # Operational period duration
    op_number = length(op_duration)   # Number of operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods.
    # This implies, that a strategic period is 7*24 times longer than an operational period,
    # resulting in the values below as "/168h".
    op_per_strat = sum(op_duration)

    # Create the time structure and global data
    T = TwoLevel(2, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO2 in t/168h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO2 in EUR/t
        CO2,                            # CO2 instance
    )

    # Create a source for the first reservoir
    # It is crucial that the source node to the first reservoire does not have a capacity.
    # The Water resource must be an output.
    # It is our aim in later versions to remove this necessity.
    source = RefSource(
        "source",               # Node ID
        FixedProfile(0),
        FixedProfile(0),
        FixedProfile(0),
        Dict(Water => 1.0)
    )

    # Define the conversion factor between m³/s and Mm³/h
    m3s_to_mm3 = 3.6e-3

    # Create two hydro reservoirs
    reservoir_up = HydroReservoir{CyclicStrategic}(
        "hydro_reservoir_up",   # Node ID
        StorCap(
            FixedProfile(10),   # Storage volume of the reservoir with a maximum capacity in Mm³
        ),
        FixedProfile(10 * m3s_to_mm3),  # Inflow to the reservoir in Mm³/h
        Water,                  # Stored resource
    )

    reservoir_down = HydroReservoir{CyclicStrategic}(
        "hydro_reservoir_down", # Node ID
        StorCap(
            FixedProfile(10),   # Storage volume of the reservoir with a maximum capacity in Mm³
        ),
        FixedProfile(0),        # Inflow to the reservoir in Mm³/h
        Water,                  # Stored resource
    )

    # Define two generators
    hydro_gen_cap_up = 20
    hydro_generator_up = HydroGenerator(
        "hydro_generator_up",   # Node ID
        FixedProfile(hydro_gen_cap_up), # Installed electricity generation capacity in MW
        PqPoints(
            [0, 10, 20] / hydro_gen_cap_up,
            [0, 10, 22] * m3s_to_mm3 / hydro_gen_cap_up
        ),
        # Lines above
        # Unitless PQ-curve - 20 MW production requires 22 m³/s discharge while 10 MW are
        # achieved with 10 m³/s discharge
        FixedProfile(0),        # Variable OPEX in EUR/MWh
        FixedProfile(0),        # Fixed OPEX in EUR/MW/168h
        Power,                  # Electricity resource used in the system
        Water,                  # Water resource used in the system
    )

    hydro_generator_down = HydroGenerator(
        "hydro_generator_down", # Node ID
        FixedProfile(hydro_gen_cap_up), # Installed electricity generation capacity in MW
        PqPoints(
            [0, 10, 20] / hydro_gen_cap_up,
            [0, 10, 22] * m3s_to_mm3 / hydro_gen_cap_up
        ),
        # Lines above
        # Unitless PQ-curve - 20 MW production requires 22 m³/s discharge while 10 MW are
        # achieved with 10 m³/s discharge
        FixedProfile(0),        # Variable OPEX in EUR/MWh
        FixedProfile(0),        # Fixed OPEX in EUR/MW/168h
        Power,                  # Electricity resource used in the system
        Water,                  # Water resource used in the system
    )

    hydro_pump_cap = 30
    hydro_pump = HydroPump(
        "hydro_pump",           # Node ID
        FixedProfile(hydro_pump_cap),   # Installed pumping capacity in MW
        PqPoints(
            [0, 15, 30] / hydro_pump_cap,
            [0, 12, 20] * m3s_to_mm3 / hydro_pump_cap
        ),
        # Lines above
        # Unitless PQ-curve - 30 MW are required to pump 20 m³/s while 15 MW are required
        # for 12 m³/s
        FixedProfile(0),        # Variable OPEX in EUR/MWh
        FixedProfile(0),        # Fixed OPEX in EUR/MW/168h
        Power,                  # Electricity resource used in the system
        Water,                  # Water resource used in the system
    )

    hydro_gate = HydroGate(
        "hydro_gate",           # Node ID
        FixedProfile(20 * m3s_to_mm3), # Maximum discharge through the gate in Mm³/h
        FixedProfile(0),        # Variable OPEX in EUR/MWh
        FixedProfile(0),        # Fixed OPEX in EUR/MW/168h
        Water,                  # Water resource used in the system
    )

    # Define a sink representing the ocean
    # It is crucial that the sink node does not have any penalties.
    # The Water resource must be an input.
    ocean = RefSink(
        "ocean",
        FixedProfile(0),
        Dict(
            :surplus => FixedProfile(0),
            :deficit => FixedProfile(0)
        ),
        Dict(Water => 1.0)
    )

    # Create an busbar (availability node) to collect electricity production and consumption
    # It is crucial that it does not contain the water resource!
    av = GenAvailability(1, [Power])

    # Create source and sink representing the electricity market
    price = [10, 60, 15, 62]
    market_sale = RefSink(
        "market_sale",          # Node id
        FixedProfile(0),        # Demand in MW
        Dict(
            :surplus => OperationalProfile(-price),
            :deficit => OperationalProfile(price)
        ),
        # Line above: Surplus and deficit penalty for the node in EUR/MWh
        Dict(Power => 1),           # Energy demand and corresponding ratio
    )
    market_buy = RefSource(
        "market_buy",           # Node id
        FixedProfile(1000),     # Capacity in MW
        OperationalProfile(price .+ 0.01),  # Variable OPEX in EUR/MWh
        FixedProfile(0),        # Fixed OPEX in EUR/MW/168h
        Dict(Power => 1.0)      # Energy supply and corresponding ratio
    )

    nodes = [
        source, reservoir_up, reservoir_down, hydro_generator_up, hydro_generator_down,
        hydro_pump, hydro_gate, ocean, av, market_sale, market_buy
    ]

    # The individual connections showcase that it is not necessary to connect all individual
    # nodes to the busbar (Availability node).
    links = [
        Direct("source-res_up", source, reservoir_up),
        Direct("res_up-gen_up", reservoir_up, hydro_generator_up),
        Direct("res_up-gate", reservoir_up, hydro_gate),
        Direct("gen_up-res_down", hydro_generator_up, reservoir_down),
        Direct("gate-res_down", hydro_gate, reservoir_down),
        Direct("res_down-pump", reservoir_down, hydro_pump),
        Direct("pump-gen_up", hydro_pump, reservoir_up),
        Direct("res_down-gen_down", reservoir_down, hydro_generator_down),
        Direct("gen_down-ocean", hydro_generator_down, ocean),
        Direct("gen_up-availability", hydro_generator_up, av),
        Direct("gen_down-availability", hydro_generator_down, av),
        Direct("availability-pump", av, hydro_pump),
        Direct("availability-market_sale", av, market_sale),
        Direct("market_buy-availability", market_buy, av),
    ]

    # WIP data structure
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T
    )

    return case, model
end

# Generate the case and model data and run the model
case, model = generate_detailed_hydropower()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = EMB.run_model(case, model, optimizer)

"""
    process_det_hydro_results(m, case)

Function for processing the results to be represented in the a table afterwards.
"""
function process_det_hydro_results(m, case)
    # Extract the nodes and the first strategic period from the data
    upper, lower, generator_up, generator_low, pump = case[:nodes][[2,3,4,5,6]]
    sp1 = first(strategic_periods(case[:T]))

    # System variables
    lvl_up = JuMP.Containers.rowtable(      # Upper reservoir level
        value,
        m[:stor_level][upper, collect(sp1)];
        header=[:t, :level]
    )
    lvl_low = JuMP.Containers.rowtable(     # Lower reservoir level
        value,
        m[:stor_level][lower, collect(sp1)];
        header=[:t, :level]
    )
    gen_up = JuMP.Containers.rowtable(      # Upper generator
        value,
        m[:cap_use][generator_up, collect(sp1)];
        header=[:t, :gen]
    )
    gen_low = JuMP.Containers.rowtable(     # Lower generator
        value,
        m[:cap_use][generator_low, collect(sp1)];
        header=[:t, :gen]
    )
    pump_l = JuMP.Containers.rowtable(      # Pump
        value,
        m[:cap_use][pump, collect(sp1)];
        header=[:t, :gen]
    )

    # Set up the individual named tuples as a single named tuple
    table = [(
            t = repr(con_1.t),
            Upper_level = round(con_1.level; digits=2),
            Lower_level = round(con_2.level; digits=2),
            Upper_generator = round(con_3.gen; digits=2),
            Lower_generator = round(con_4.gen; digits=2),
            Pump = round(con_5.gen; digits=2),
        ) for (con_1, con_2, con_3, con_4, con_5) ∈ zip(lvl_up, lvl_low, gen_up, gen_low, pump_l)
    ]
    return table
end

# Display some results
table = process_det_hydro_results(m, case)
@info(
    "Individual results from the hydro power system:\n" *
    " - Generation and pumping never occurs simultaneously.\n" *
    " - It is beneficial to limit the production to the periods with high prices while\n" *
    "   buying from the market at low prices for pumping between the reservoirs.\n" *
    " - The lower reservoir is not emptied in `sp1-t4` to be able to pump water in `sp1-1`\n" *
    "   to the upper reservoir at low prices.\n"
)
pretty_table(table)
