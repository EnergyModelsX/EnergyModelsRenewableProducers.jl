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
the figure in the documentation.
The `RefSource` is connected to the upper `HydroReservoir` to ensure the reservoir always
has at least one input.
The upper and lower `HydroReservoir` are connected through a `HydroGenerator`, a
`HydroPump`, and a `HydroGate`.
The lower `HydroReservoir` and the `RefSink` representing the ocean are connected through a
`HydroGenerator`.
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
    op_duration = [1, 1, 2, 4] # Operational period duration
    op_number = length(op_duration)   # Number of operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

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

    # Create a source for the first reservoir
    source = RefSource(
        "source",
        FixedProfile(0),
        FixedProfile(0),
        FixedProfile(0),
        Dict(Water => 1.0)
    )

    # Define conversion factor between m³/s and Mm³/h
    m3s_to_mm3 = 3.6e-3
    # Create two hydro reservoirs
    reservoir_up = HydroReservoir{CyclicStrategic}(
        "hydro_reservoir_up",  # Node ID
        StorCap(
            FixedProfile(10), # volume, maximum capacity in Mm³
        ),
        FixedProfile(10 * m3s_to_mm3),   # inflow in Mm³/h
        Water,              # stor_res, stored resource
    )

    reservoir_down = HydroReservoir{CyclicStrategic}(
        "hydro_reservoir_down",  # Node ID
        StorCap(
            FixedProfile(10), # vol, maximum capacity in Mm³
        ),
        FixedProfile(0),   # inflow in Mm³/h
        Water,              # stor_res, stored resource
    )

    # Define two generators
    hydro_gen_cap_up = 20 # MW
    hydro_generator_up = HydroGenerator(
        "hydro_generator_up",
        FixedProfile(hydro_gen_cap_up),                # Installed discharge capacity
        PqPoints(
            [0, 10, 20] / hydro_gen_cap_up,
            [0, 10, 22] * m3s_to_mm3 / hydro_gen_cap_up
        ),          # Unitless PQ-curve - 20 MW production requires 22 m³/s
        FixedProfile(0),   # opex_var
        FixedProfile(0),   # opex_fixed
        Power,
        Water
    )

    hydro_generator_down = HydroGenerator(
        "hydro_generator_down",
        FixedProfile(hydro_gen_cap_up),                # Installed discharge capacity
        PqPoints(
            [0, 10, 20] / hydro_gen_cap_up,
            [0, 10, 22] * m3s_to_mm3 / hydro_gen_cap_up
        ),          # Unitless PQ-curve - 20 MW production requires 22 m³/s
        FixedProfile(0),   # opex_var
        FixedProfile(0),   # opex_fixed
        Power,
        Water
    )

    hydro_pump_cap = 30
    hydro_pump = HydroPump(
        "hydro_pump",
        FixedProfile(hydro_pump_cap),                # Installed pumping capacity
        PqPoints(
            [0, 15, 30] / hydro_pump_cap,
            [0, 12, 20] * m3s_to_mm3 / hydro_pump_cap
        ),          # PQ-curve
        FixedProfile(0),   # opex_var
        FixedProfile(0),   # opex_fixed
        Power,
        Water
    )

    hydro_gate = HydroGate(
        "hydro_gate",
        FixedProfile(20 * m3s_to_mm3), # capacity
        FixedProfile(0),               # opex_var
        FixedProfile(0),               # opex_fixed
        Water
    )

    # Define a sink representing the ocean
    ocean = RefSink(
        "ocean",
        FixedProfile(0),
        Dict(
            :surplus => FixedProfile(0),
            :deficit => FixedProfile(0)
        ),
        Dict(Water => 1.0)
    )

    # Create an busbar (availability) node to collect electricity production and consumption
    av = GenAvailability(1, [Power])

    # Create source and sink representing the electricity market
    price = [10, 60, 15, 65]
    market_sale = RefSink(
        "market_sale",
        FixedProfile(0),
        Dict(
            :surplus => OperationalProfile(-price),
            :deficit => OperationalProfile(price)
        ),
        Dict(Power => 1.0)
    )

    market_buy = RefSource(
        "market_buy",
        FixedProfile(1000),
        OperationalProfile(price .+ 0.01),
        FixedProfile(0),
        Dict(Power => 1.0)
    )

    nodes = [
        source, reservoir_up, reservoir_down, hydro_generator_up, hydro_generator_down,
        hydro_pump, hydro_gate, ocean, av, market_sale, market_buy
    ]

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
        Direct("market_buy-availability", market_buy, av)
    ]

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

# Display some results
@info "Storage level of the hydro reservoir up"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:stor_level][case[:nodes][2], :];
        header = [:TimePeriod, :Level],
    ),
)
@info "Market sale"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:flow_in][case[:nodes][end-1], :, case[:products][2]];
        header = [:TimePeriod, :Production],
    ),
)

@info "Market buy"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:flow_out][case[:nodes][end], :, case[:products][2]];
        header = [:TimePeriod, :Production],
    ),
)
