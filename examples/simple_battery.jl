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
    generate_battery_example_data()

Generate the data for an example consisting of a simple electricity network with a electricity
source with varying prices, a reserve battery, an electricity demand, and the demand for a
down reserve.
It illustrates the behavior of the reserve battery and how it can both store energy and
provide reserve capacity
"""
function generate_battery_example_data()
    @info "Generate case data - Simple `ReserveBattery` example"

    # Define the different resources and their emission intensity in tCO2/MWh
    # CO2 has to be defined, even if not used, as it is required for the `EnergyModel` type
    CO2 = ResourceEmit("CO2", 1.0)
    power = ResourceCarrier("power", 0.0)
    reserve_down = ResourceCarrier("reserve up", 0.0)
    products = [power, CO2, reserve_down]

    # Variables for the individual entries of the time structure:
    # - There are in total 10 operational periods.
    # - The duration of the individual operational periods vary between 6 h and 3 h. The 10
    #   periods correspond to 48 h.
    op_duration = [6, 3, 6, 3, 6, 6, 3, 6, 3, 6]
    op_number = 10
    operational_periods = SimpleTimes(op_number, op_duration)

    # The duration 1 of an operational period (1 h) is repeated 8760.0 for the duration 1 of
    # a strategic period. A strategic period corresponds hence to 1 year.
    op_per_strat = 8760.0

    # Creation of the time structure and global data
    # - There are in total 3 strategic periods.
    # - Each strategic periods has a duration of 2 years.
    T = TwoLevel(4, 2, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO2 in t/a
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO2 in EUR/t
        CO2,                            # CO2 instance
    )

    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink, the requirement for a reserve, a battery, and an electricity source
    el_demand = OperationalProfile([16; 28; 20; 25; 18; 15; 25; 20; 28; 18])
    supply_price = OperationalProfile([30; 80; 60; 80; 40; 30; 80; 60; 80; 40])
    source = RefSource(
        "source",               # Node ID
        FixedProfile(20),       # Capacity in MW
        supply_price,           # Variable OPEX (electricity price) in EUR/MW
        FixedProfile(10),       # Fixed OPEX in EUR/a
        Dict(power => 1),       # Output from the Node, in this case, power
    )
    battery = ReserveBattery{CyclicStrategic}(
        "battery",
        StorCap(FixedProfile(20)),  # Charge capacity in MW
        StorCap(FixedProfile(50)),  # Storage level capacity in MWh
        StorCap(FixedProfile(20)),  # Discharge capacity in MW
        power,                  # Stored resource
        Dict(power => 0.9),     # Input resource with charge efficiency
        Dict(power => 0.9),     # Output resource with discharge efficiency
        CycleLife(
            900,                # Cycles before the battery reach the end of its lifetime
            0.2,                # Capacity reduction at the end of the lifetime
            FixedProfile(2e5),  # Battery stack replacement cost in EUR/MWh
        ),
        ResourceCarrier[],      # Upwards reserve resource
        [reserve_down],         # Downwards reserve resource, not included
    )
    sink = RefSink(
        "electricity demand",   # Node id
        el_demand,              # Demand in MW
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e3)),
        # Line above: Surplus and deficit penalty for the node in EUR/MWh
        Dict(power => 1),       # Energy demand and corresponding ratio
    )
    reserve_up_sink = RefSink(
        "reserve down demand",  # Node id
        FixedProfile(10),       # Required reserve capacity in MW
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e2)),
        # Line above: Surplus and deficit penalty for the node in EUR/MWh
        Dict(reserve_down => 1),# Energy demand and corresponding ratio
    )
    nodes = [source, battery, sink, reserve_up_sink]

    # Connect the two nodes with each other
    # The source node can either directly deliver electricity to the demand or via the
    # battery
    links = [
        Direct("source-battery", nodes[1], nodes[2])
        Direct("source-demand", nodes[1], nodes[3])
        Direct("battery-demand", nodes[2], nodes[3])
        Direct("battery-reserve_down", nodes[2], nodes[4])
    ]

    # Create the case dictionary
    case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

    return case, model
end

# Generate the case and model data and run the model
case, model = generate_battery_example_data()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = EMB.run_model(case, model, optimizer)

"""
    process_battery_results(m, case)

Function for processing the results to be represented in the a table afterwards.
"""
function process_battery_results(m, case)
    # Extract the nodes and the first strategic period from the data
    source, bat, sink = case[:nodes][[1, 2, 3]]
    𝒯ᴵⁿᵛ = strategic_periods(case[:T])
    ops = collect(case[:T])[1:20]

    # System variables for operational periods
    source_use = JuMP.Containers.rowtable(      # Source usage
        value,
        m[:cap_use][source, ops];
        header=[:t, :source]
    )
    bat_ch = JuMP.Containers.rowtable(          # Battery charge
        value,
        m[:stor_charge_use][bat, ops];
        header=[:t, :charge]
    )
    bat_lvl = JuMP.Containers.rowtable(         # Battery level
        value,
        m[:stor_level][bat, ops];
        header=[:t, :level]
    )
    bat_dch = JuMP.Containers.rowtable(         # Battery discharge
        value,
        m[:stor_discharge_use][bat, ops];
        header=[:t, :discharge]
    )
    sink_deficit = JuMP.Containers.rowtable(    # Sink deficit
        value,
        m[:sink_deficit][sink, ops];
        header=[:t, :deficit]
    )
    price = opex_var(source)[ops]
    demand = capacity(sink)[ops]

    # Set up the individual named tuples as a single named tuple
    table_op = [(
            t = repr(con_1.t),
            Source = round(con_1.source; digits=2),
            Price = con_2,
            Demand = con_3,
            Battery_charge = round(con_4.charge; digits=2),
            Battery_level = round(con_5.level; digits=2),
            Battery_discharge = round(con_6.discharge; digits=2),
            Deficit = round(con_7.deficit; digits=2),
        ) for (con_1, con_2, con_3, con_4, con_5, con_6, con_7) ∈
            zip(source_use, price, demand, bat_ch, bat_lvl, bat_dch, sink_deficit)
    ]

    # System variables for strategic periods
    total_charge = JuMP.Containers.rowtable(    # Battery usage up to the sp as cycles
        value,
        m[:bat_prev_use_sp][bat, collect(𝒯ᴵⁿᵛ)]./50;
        header=[:sp, :prev_use]
    )
    use_sp = JuMP.Containers.rowtable(          # Battery usage in the sp as cycles
        value,
        m[:bat_use_sp][bat, collect(𝒯ᴵⁿᵛ)]./50;
        header=[:sp, :use_sp]
    )
    replace = JuMP.Containers.rowtable(         # Battery stack replacement
        value,
        m[:bat_stack_replace_b][bat, collect(𝒯ᴵⁿᵛ)];
        header=[:sp, :replace]
    )

    # Set up the individual named tuples as a single named tuple
    table_sp = [(
            sp = repr(con_1.sp),
            Previous_use = round(con_1.prev_use; digits=1),
            Use = round(con_2.use_sp; digits=1),
            Replacement = round(con_3.replace; digits=1),
        ) for (con_1, con_2, con_3) ∈ zip(total_charge, use_sp, replace)
    ]

    return table_op, table_sp
end

# Display some results
table_op, table_sp = process_battery_results(m, case)
@info(
    "Individual results from the battery system in the first strategic period:\n" *
    " - The electricity source is used fully in all periods.\n" *
    " - The battery charges in periods with lower electricity demand and prices (1, 5, 6, and 10) \n" *
    "   and discharges in periods with higher demands and prices (2, 4, 7, and 9).\n" *
    " - The efficiencies are visible as the charge does not directly relate to a similar increas \n" *
    "   in the level and the duration of the period.\n" *
    " - The maximum storage level is not used as the battery provides a reserve of 10 MW.\n"
)
pretty_table(table_op[1:5])
pretty_table(table_op[6:10])
@info(
    "Individual results from the battery system in the second strategic period:\n" *
    " - The battery operation changes as the maximum storage level is reduced due to degradation.\n" *
    " - While it still charges and discharges at periods with high and low prices, its level \n" *
    "   is behaving differently.\n" *
    " - The source is no longer fully used due to issues in storage capacity.\n"
)
pretty_table(table_op[11:15])
pretty_table(table_op[16:20])


@info(
    "Individual results from the battery system in strategic priods:\n" *
    " - The previous usage is 0 in periods with a fresh battery stack (1 and 3).\n" *
    " - The previous usage is twice the use values in the other periods as the duration \n" *
    "   of a strategic period is 2.\n" *
    " - The use in periods with previous usage is lower due to a reduction in the capacity \n" *
    "   due to the usage and the maximum cycle life.\n"
)
pretty_table(table_sp)
