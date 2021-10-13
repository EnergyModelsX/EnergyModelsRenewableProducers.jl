if abspath(PROGRAM_FILE) == @__FILE__
    import Pkg
    Pkg.activate(@__DIR__)
    Pkg.instantiate()

    const IS_SCRIPT = true
end

using EnergyModelsBase
using Geography
using GLPK
using InvestmentModels
using JuMP
using RenewableProducers
using TimeStructures

const EMB = EnergyModelsBase
const GEO = Geography
const IM = InvestmentModels
const RP = RenewableProducers

NG = ResourceEmit("NG", 0.2)
Coal     = ResourceCarrier("Coal", 0.35)
Power = ResourceCarrier("Power", 0.)
CO2 = ResourceEmit("CO2", 1.)
products = [Power, CO2]
𝒫₀ = Dict(k=>0 for k ∈ products)
𝒫ᵉᵐ₀ = Dict(k=>0 for k ∈ products if isa(k, ResourceEmit))


function agder_nodes(𝒯)

    # investment_data = IM.extra_inv_data_storage(
    #     FixedProfile(2700), # capex [€/kW]
    #     FixedProfile(4e6), # FIX # max_inst_cap [kW]
    #     FixedProfile(0), # max_add [kW]
    #     FixedProfile(0), # min_add [kW]
    #     IM.ContinuousInvestment() # investment mode
    # )

    max_storage = FixedProfile(1e8)
    initial_reservoir = FixedProfile(1e7)
    min_level = FixedProfile(0.1)
    
    hydro = RP.RegHydroStor("-agd:hydro", FixedProfile(1e6), max_storage, 
        true, initial_reservoir, FixedProfile(5e4), min_level, 
        FixedProfile(30/1e3), FixedProfile(10),
        Dict(Power=>0.95), Dict(Power=>0.95), 
        Dict(CO2=>27), Dict(""=> EMB.EmptyData()))

    agder_av = Geography.GeoAvailability("-agd:av", 𝒫₀, 𝒫₀)

    agder_area = Geography.Area("agder", "Agder", 58.02722, 7.44889, agder_av)
        
    nodes = [agder_av, hydro] 
    links = [EMB.Direct("a:av-h", nodes[1], nodes[2], EMB.Linear()), 
             EMB.Direct("a:h-av", nodes[2], nodes[1], EMB.Linear())]

    return agder_area, agder_av, nodes, links 
end

function nord_nodes(𝒯)
    # Mean ≈ 0.45
    profile = DynamicProfile([
        0.4 0.33 0.04 0.38 0.17 0.51 0.0 0.73 0.31 0.27 0.48 0.37 0.55 0.85 0.43 0.96 0.75 1.0 0.23 0.17 0.19 0.37 0.64 0.46 1.0 0.64 0.55 0.51 0.39 0.56 0.38 0.76 1.0 0.95 0.19 0.06 0.08 0.23 0.91 1.0;
        1.0 0.83 0.49 0.0 0.1 0.06 0.53 0.65 1.0 0.26 0.03 0.22 0.0 0.47 0.66 0.82 0.01 0.39 0.38 0.19 0.3 0.0 0.64 0.23 0.73 0.86 0.32 0.38 0.26 0.37 0.05 0.33 0.82 0.65 0.98 0.26 0.18 0.48 0.69 0.76;
        1.0 0.94 0.52 0.34 0.0 0.28 0.69 0.24 0.01 0.72 0.04 0.59 0.0 0.51 0.0 1.0 1.0 0.8 0.51 0.16 0.26 0.5 0.0 1.0 0.81 0.0 0.27 0.22 0.08 0.34 0.21 0.7 0.17 0.12 0.34 0.0 0.11 0.18 0.34 1.0;
        0.15 0.64 0.27 0.05 0.06 0.54 0.9 1.0 1.0 0.75 0.13 0.0 0.0 0.56 0.66 0.74 1.0 0.85 0.38 0.09 0.07 0.66 0.22 0.54 0.28 0.29 0.0 0.07 0.19 0.35 0.29 0.87 0.28 1.0 0.2 0.0 0.13 0.28 0.0 0.51;
    ])

    investment_data = IM.extra_inv_data(
        Capex_Cap= FixedProfile(2700), # capex [€/kW] # TODO sjekk enheter
        Cap_max_inst = FixedProfile(1e10), # FIX # max installed capacity [kW]
        Cap_max_add = FixedProfile(5e6), # max_add [kW]
        Cap_min_add = FixedProfile(0), # min_add [kW]
        Inv_mode = IM.ContinuousInvestment() # investment mode
    )
    wind = RP.NonDisRES("-nrd:wind", FixedProfile(0), profile,
        FixedProfile(1000 * 1e-6), # var_opex [€/kW(op.duration h)]
        FixedProfile(100), # fixed_opex [€/kW/(duration years)]
        Dict(Power=>1), Dict(CO2=>11), Dict("InvestmentModels"=>investment_data))

    nords_av = GEO.GeoAvailability("-nrd:av", 𝒫₀, 𝒫₀)
    nords_area = GEO.Area("nordsjøen", "Nordsjøen", 56.023, 3.164, nords_av)

    nodes = [nords_av, wind]
    links = [EMB.Direct("n:w-av", nodes[2], nodes[1], EMB.Linear())]

    return nords_area, nords_av, nodes, links
end


""" 
var_opex_src [€/GWh]
"""
function denmark_nodes(𝒯, var_opex_src)

    # TODO add Source? FixedStrategic for source. Sink: mindre om natten enn dagen, mer om vinter enn om dagen
    # source, sink

    # investment_data_source = IM.extra_inv_data(
    #     FixedProfile(1200), # capex [€/kW]
    #     FixedProfile(1e6), # FIX! # max installed capacity [kW]
    #     FixedProfile(0), # max_add [kW]
    #     FixedProfile(0), # min_add [kW]
    #     IM.ContinuousInvestment() # investment mode
    # )
    source = EMB.RefSource("-den:src", FixedProfile(1e6), # id, capacity [kW]
        FixedProfile(var_opex_src * 1e-6), # var_opex [€/kW(op.duration h)]
        FixedProfile(1000), # fixed_opex TODO ok?
        Dict(Power=>1), # output
        Dict(CO2=>150), # emissions 150g/kWh for Denmark  
        Dict(""=> EMB.EmptyData())
        # Dict("InvestmentModels"=>investment_data_source)
    )

    sink = EMB.RefSink("-den:sink", FixedProfile(1e6), # id, capacity
        Dict(:Surplus=>0, :Deficit=>1e3), # penalty 
        Dict(Power => 1), # input
        Dict(CO2=>0) # emissions
    )

    den_av = GEO.GeoAvailability("-den:av",  𝒫₀, 𝒫₀)
    den_area = GEO.Area("den", "Danmark", 56.0966, 8.2178, den_av)

    nodes = [den_av, sink, source]
    links = [
        EMB.Direct("den:src-av", nodes[3], nodes[1], EMB.Linear()),
        EMB.Direct("den:av-sink", nodes[1], nodes[2], EMB.Linear()),
    ]
    
    return den_area, den_av, nodes, links
end


function get_data(var_opex_src)
    T = UniformTwoLevel(1, 4, 5, UniformTimes(1, 40, 5 * 8760/40)) #0, 219))

    agd_area, agd_av, agd_nodes, agd_links = agder_nodes(T)
    nor_area, nor_av, nor_nodes, nor_links = nord_nodes(T)
    den_area, den_av, den_nodes, den_links = denmark_nodes(T, var_opex_src)

    nodes = [den_nodes..., nor_nodes..., agd_nodes...]
    links = [den_links..., nor_links..., agd_links...]

    trm_line = GEO.RefStatic("cable", Power, 1e7, 0.05, 1)
    transmissions = []

    # Comment out agd_area from this array to run the case without the hydrostorage.
    areas = [den_area, nor_area, agd_area]
    
    for a1 in areas, a2 in areas
        a1 != a2 && push!(transmissions, GEO.Transmission(a1, a2, [trm_line],  [Dict(""=> EMB.EmptyData())]))
    end

    return Dict(
        :nodes=>nodes, 
        :links=>links, 
        :products=>[Power, CO2], 
        :areas=>areas,
        :transmission=>transmissions,
        :T=>T)
end


function run_case_model(optimizer, data, case, discount_rate=0.05)
    model = IM.InvestmentModel(case, discount_rate)
    m = GEO.create_model(data, model)

    if !isnothing(optimizer)
        set_optimizer(m, optimizer)
        optimize!(m)
        # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
        # TODO: save_solution(m) save results
    else
        @info "No optimizer given"
    end
    return m
end





function run_demo(prices = [0, 1000, 10000, 50000, 75000, 100000, 150000, 200000, 250000, 300000, 350000, 400000, 450000, 500000])
    investments = []
    used_capacity = []
    curtailment = []

    for var_opex_src in prices
        # var_opex_src is the price of production by the source in €/GWh
        data = get_data(var_opex_src)

        # CO2 price
        price = StrategicFixedProfile([50e-6, 60e-6, 70e-6, 80e-6])
        # price = FixedProfile(50e-6)
        case = IM.StrategicCase(StrategicFixedProfile([1e11, 1e11, 1e11, 1e11]),
            Dict(CO2=>price))
        discount_rate = 0.07
        m = run_case_model(GLPK.Optimizer, data, case, discount_rate)

        println("=======================")
        println()
        source = data[:nodes][3]
        sink = data[:nodes][2]
        wind = data[:nodes][5]
        hydro = data[:nodes][7]
        T = data[:T]
        println("pris ", var_opex_src * 1e-6, " €/kWh")
        println()
        println("source ", sum(value.(m[:cap_use][source, t]) for t in T))
        println("sink ", sum(value.(m[:cap_use][sink, t]) for t in T))
        println("wind ", sum(value.(m[:cap_use][wind, t]) for t in T))
        println("hydro ", sum(value.(m[:stor_rate_use][hydro, t]) for t in T))
        println()
        @show value.(m[:cap_add])
        
        # Calculate the total investments in offshore wind.
        push!(investments, sum(value.(m[:cap_add][wind, t]) for t ∈ strategic_periods(T)))

        # Compute average used capacity for the hy
        used_capacities = []
        for t in T
            used_op = value.(m[:cap_use][wind, t]) / (value.(m[:cap_inst][wind, t]) * wind.Profile[t])
            # curtailment_op = value.(m[:curtailment][wind, t]) / value.(m[:cap_inst])
            if value.(m[:cap_inst][wind, t]) * wind.Profile[t] != 0
                push!(used_capacities, used_op)
            else
                push!(used_capacities, 0)
            end
        end
        push!(used_capacity, sum(used_capacities) / length(used_capacities))

    end

    println()
    @show prices
    @show investments
    @show used_capacity
end

if IS_SCRIPT
    run_demo()
end