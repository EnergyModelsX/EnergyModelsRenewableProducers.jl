using Revise
using Pkg
# Activate the local environment including EnergyModelsRenewableProducers, HiGHS, PrettyTables
Pkg.activate(@__DIR__)
# Resolve environment (in case of changes)
Pkg.resolve()
Pkg.develop(path=joinpath(@__DIR__, ".."))
#Pkg.activate()
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
#include("C:\\Users\\linn\\OneDrive - SINTEF\\Prosjekter\\iDesignRes\\EMX\\EnergyModelsRenewableProducers.jl\\src\\added_datastruct.jl")


@info "Generate case data - Simple `HydroStor` example"

# Define the different resources and their emission intensity in tCO2/MWh
# CO2 has to be defined, even if not used, as it is required for the `EnergyModel` type
CO2 = ResourceEmit("CO2", 1.0)
Power = ResourceCarrier("Power", 0.0)
Water = ResourceCarrier("Water", 0.0)
products = [CO2, Power, Water]

# Variables for the individual entries of the time structure
op_duration = 2 # Each operational period has a duration of 2
op_number = 4   # There are in total 4 operational periods
operational_periods = SimpleTimes(op_number, op_duration)

# The number of operational periods times the duration of the operational periods.
# This implies, that a strategic period is 8 times longer than an operational period,
# resulting in the values below as "/8h".
op_per_strat = op_duration * op_number

# Create the time structure and global data
T = TwoLevel(2, 1, operational_periods; op_per_strat)
model = OperationalModel(
    Dict(CO2 => FixedProfile(10)),  # Emission cap for CO2 in t/8h
    Dict(CO2 => FixedProfile(0)),   # Emission price for CO2 in EUR/t
    CO2,                            # CO2 instance
)
# Create the Availability/bus node for the system
av = GenAvailability(1, products)

# Create a non-dispatchable renewable energy source
wind = NonDisRES(
    "wind",             # Node ID
    FixedProfile(2),    # Capacity in MW
    OperationalProfile([0.9, 0.4, 0.1, 0.8]), # Profile
    FixedProfile(5),    # Variable OPEX in EUR/MW
    FixedProfile(10),   # Fixed OPEX in EUR/8h
    Dict(Power => 1),   # Output from the Node, in this gase, Power
)


# Create a regulated hydro power plant without storage capacity
hydro = HydroStor(
    "hydropower",       # Node ID
    FixedProfile(2.0),  # Rate capacity in MW
    FixedProfile(90),   # Storage capacity in MWh
    FixedProfile(10),   # Initial storage level in MWh
    FixedProfile(1),    # Inflow to the Node in MW
    FixedProfile(0.0),  # Minimum storage level as fraction
    FixedProfile(8),    # Variable OPEX in EUR/MWh
    FixedProfile(3),    # Fixed OPEX in EUR/8h
    Power,              # Stored resource
    Dict(Power => 0.9), # Input to the power plant, irrelevant in this case
    Dict(Power => 1),   # Output from the Node, in this gase, Power
    Data[],             # Potential additional data
)

inflow = Inflow(    
    "inflow",           # Node ID
    FixedProfile(1000), # Capacity of inflow source (only included tbecause it is required)
    FixedProfile(0),    # Inflow in mm3/hour
    FixedProfile(0),    # Variable OPEX in EUR/MWh
    FixedProfile(0),    # Fixed OPEX in EUR/MWh
    Dict(Water => 1),   # Output from the Node, in this case, Power
    Data[],
    )

hydro_reservoir = HydroReservoir(
    "hydro_reservoir",  # Node ID
    FixedProfile(10),   # rate_cap, capacity pump/discharge in mm3/timestep
    FixedProfile(100),  # stor_cap, capacity reservoir in mm3
    FixedProfile(10),   # level_int, initial water level in mm3
    #FixedProfile(0),    # level_min, minimum water level in mm3
    #FixedProfile(100),  # level_max, maximum water level in mm3
    FixedProfile(0),    # opex_var, variable OPEX in EUR/(mm3/h?)
    FixedProfile(0),    # opex_fixed, Fixed OPEX in EUR/(mm3/h?)
    Water,              # stor_res, stored resource 
    #Dict(0 => 0, 100 => 10),        # vol_head
    #Dict(1 => Dict(0.0 => 0.0)),    # water_value
    Dict(Water => 1),               # input
    Dict(Water => 1),               # output
    Data[],                         
)

reservoir_disch = HydroGate(
    "discharge_reservoir",  # Node ID
    FixedProfile(10),       # cap, in mm3/timestep
    FixedProfile(0),        # opex_var, variable OPEX in EUR/(mm3/h?)
    FixedProfile(0),        # opex_fixed, Fixed OPEX in EUR/(mm3/h?)
    Dict(Water => 1),       # input
    Dict(Water => 1),       # output
)

reservoir_spill = HydroGate(
    "discharge_reservoir",  # Node ID
    FixedProfile(1000),     # cap, in mm3/timestep
    FixedProfile(0),        # opex_var, variable OPEX in EUR/(mm3/h?)
    FixedProfile(0),        # opex_fixed, Fixed OPEX in EUR/(mm3/h?)
    Dict(Water => 1),       # input
    Dict(Water => 1),       # output
)


hydro_station = HydroStation(
    "hydropower_station",   # Node ID
    #FixedProfile(10),       # power_cap
    FixedProfile(10),       # cap
    #Dict(0 => 0, 1 => 1),   # pq_curve
    #FixedProfile(0),        # pump_power_cap
    #FixedProfile(0),        # pump_disch_cap
    #Dict(0 => 0, 1 => 1),   # pump_pq_curve
    #FixedProfile(0),        # prod_min
    #FixedProfile(Inf),      # prod_max
    FixedProfile(6),        # opex_var
    FixedProfile(0),        # opex_fixed
    Dict(Water => 1),       # input
    Dict(Water => 1, Power => 1),   # output
    Data[],                 # data
)


   # Create a final water node, ocean
   ocean = RefSink(
    "ocean",   # Node id
    FixedProfile(0),    # No demand for water
    Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(0)),
    # Line above: Surplus and deficit penalty for the node in EUR/mm3
    Dict(Water => 1),   # Resource and corresponding ratio
)


    # Create a power demand node
    sink = RefSink(
        "electricity demand",   # Node id
        FixedProfile(2),    # Demand in MW
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        # Line above: Surplus and deficit penalty for the node in EUR/MWh
        Dict(Power => 1),   # Energy demand and corresponding ratio
    )

    # Create the array of ndoes
    nodes = [av, wind, hydro, inflow, hydro_reservoir, reservoir_disch, reservoir_spill, hydro_station, ocean, sink]
    #nodes = [av, wind, hydro, inflow, hydro_reservoir]

    # Connect all nodes with the availability node for the overall energy balance
    links = [
        Direct("wind-av", wind, av),
        Direct("hy-av", hydro, av),
        Direct("av-hy", av, hydro),
        Direct("inf-hydro_res", inflow, hydro_reservoir),
        Direct("hydro_res-hydro_gate", hydro_reservoir, reservoir_disch),
        Direct("hydro_res-hydro_gate", hydro_reservoir, reservoir_spill),
        Direct("hydro_gate-hydro_station", reservoir_disch, hydro_station),
        Direct("hydro_gate-hydro_station", reservoir_spill, ocean),
        Direct("hydro_station-av",  hydro_station, av),
        Direct("av-hydro_station", av, hydro_station),
        Direct("av-demand", av, sink),
    ]

    # Create the case dictionary
    case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = EMB.run_model(case, model, optimizer)

# Display some results
@info "Storage level of the hydro power plant"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:stor_level];
        header = [:Node, :TimePeriod, :Level],
    ),
)
@info "Power production of the two power sources"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:flow_out][case[:nodes][2:3], :, case[:products][2]];
        header = [:Node, :TimePeriod, :Production],
    ),
)