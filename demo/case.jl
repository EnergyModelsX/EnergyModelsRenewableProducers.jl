const EMB = EnergyModelsBase
const GEO = Geography
const IM = InvestmentModels
const RP = RenewableProducers

NG = ResourceEmit("NG", 0.2)
Coal     = ResourceCarrier("Coal", 0.35)
Power = ResourceCarrier("Power", 0.)
CO2 = ResourceEmit("CO2", 1.)
products = [NG, Coal, Power, CO2]
𝒫₀ = Dict(k=>0 for k ∈ products)
𝒫ᵉᵐ₀ = Dict(k=>0 for k ∈ products if isa(k, ResourceEmit))


function agder_nodes(𝒯)

    investment_data = IM.extra_inv_data(
        FixedProfile(2700), # capex [€/kW]
        FixedProfile(4e6), # FIX # max_inst_cap [kW]
        1e6, # ExistingCapacity [kW]
        FixedProfile(0), # max_add [kW]
        FixedProfile(0), # min_add [kW]
        IM.ContinuousInvestment() # investment mode
    )

    max_storage = 1e8
    initial_reservoir = FixedProfile(1e7)
    min_level = FixedProfile(0.1)
    
    hydro = RP.RegHydroStor("-agd:hydro", FixedProfile(0), 
        true, initial_reservoir, max_storage, FixedProfile(5e4), min_level, 
        FixedProfile(30), FixedProfile(10), Dict(Power=>0.95), Dict(Power=>0.95), 
        Dict(NG=>0, CO2=>27), Dict("InvestmentModels"=>investment_data))

    agder_av = Geography.GeoAvailability("-agd:av", 𝒫₀, 𝒫₀)

    agder_area = Geography.Area("agder", "Agder", 58.02722, 7.44889, agder_av)
        
    nodes = [agder_av, hydro] 
    links = [EMB.Direct("a:av-h", nodes[1], nodes[2], EMB.Linear()), 
             EMB.Direct("a:h-av", nodes[2], nodes[1], EMB.Linear())]

    return agder_area, agder_av, nodes, links 
end

function nord_nodes(𝒯)
    # windprofile, snitt på 45%

    # Mean=0.45, std=0.1. TODO create a NormalDistProfile(mean, std, 𝒯, seed)?
    profile = DynamicProfile([
        0.4 0.33 0.04 0.38 0.17 0.51 0.0 0.73 0.31 0.27 0.48 0.37 0.55 0.85 0.43 0.96 0.75 1.0 0.23 0.17 0.19 0.37 0.64 0.46 1.0 0.64 0.55 0.51 0.39 0.56 0.38 0.76 1.0 0.95 0.19 0.06 0.08 0.23 0.91 1.0;
        1.0 0.83 0.49 0.0 0.1 0.06 0.53 0.65 1.0 0.26 0.03 0.22 0.0 0.47 0.66 0.82 0.01 0.39 0.38 0.19 0.3 0.0 0.64 0.23 0.73 0.86 0.32 0.38 0.26 0.37 0.05 0.33 0.82 0.65 0.98 0.26 0.18 0.48 0.69 0.76;
        1.0 0.94 0.52 0.34 0.0 0.28 0.69 0.24 0.01 0.72 0.04 0.59 0.0 0.51 0.0 1.0 1.0 0.8 0.51 0.16 0.26 0.5 0.0 1.0 0.81 0.0 0.27 0.22 0.08 0.34 0.21 0.7 0.17 0.12 0.34 0.0 0.11 0.18 0.34 1.0;
        0.15 0.64 0.27 0.05 0.06 0.54 0.9 1.0 1.0 0.75 0.13 0.0 0.0 0.56 0.66 0.74 1.0 0.85 0.38 0.09 0.07 0.66 0.22 0.54 0.28 0.29 0.0 0.07 0.19 0.35 0.29 0.87 0.28 1.0 0.2 0.0 0.13 0.28 0.0 0.51;
    ])

    investment_data = IM.extra_inv_data(
        FixedProfile(2700), # capex [€/kW] # TODO sjekk enheter
        FixedProfile(1e10), # FIX # max installed capacity [kW]
        0, # existing capacity [kW]
        FixedProfile(5e6), # max_add [kW]
        FixedProfile(0), # min_add [kW]
        IM.ContinuousInvestment() # investment mode
    )
    wind = RP.NonDisRES("-nrd:wind", FixedProfile(2), profile,
        FixedProfile(1000 * 1e-6 * 𝒯.operational.duration), # var_opex [€/kW(op.duration h)]
        FixedProfile(100 * 𝒯.duration), # fixed_opex [€/kW/(duration years)]
        Dict(Power=>1), Dict(NG=>0, CO2=>11), Dict("InvestmentModels"=>investment_data))

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

    investment_data_source = IM.extra_inv_data(
        FixedProfile(1200), # capex [€/kW]
        FixedProfile(3.5e6), # FIX! # max installed capacity [kW]
        1e6, # FIX! existing capacity [kW]
        FixedProfile(0), # max_add [kW]
        FixedProfile(0), # min_add [kW]
        IM.ContinuousInvestment() # investment mode
    )
    source = EMB.RefSource("-den:src", FixedProfile(3.5e6), # id, capacity [kW]
        FixedProfile(var_opex_src * 𝒯.operational.duration * 1e-6), # var_opex [€/kW(op.duration h)]
        FixedProfile(1000 * 𝒯.duration), # fixed_opex TODO ok?
        Dict(Power=>1), # output
        Dict(CO2=>150, NG => 0), # emissions 150g/kWh for Denmark  
        Dict("InvestmentModels"=>investment_data_source)
    )

    sink = EMB.RefSink("-den:sink", FixedProfile(1e6), # id, capacity
        Dict(:surplus=>0, :deficit=>1e6), # penalty 
        Dict(Power => 1), # input
        Dict(NG=>0, CO2=>0) # emissions
    )

    #=  TODO not use wind node in Denmark?
    # Mean=0.25, std=0.1
    wind_profile = DynamicProfile([
        0.05 0.2 0.24 0.31 0.24 0.23 0.26 0.14 0.41 0.22 0.05 0.25 0.23 0.2 0.14 0.23 0.33 0.3 0.31 0.33 0.26 0.23 0.17 0.31 0.35 0.18 0.34 0.16 0.14 0.32 0.42 0.16 0.07 0.14 0.39 0.52 0.34 0.22 0.35 0.07;
        .05 0.21 0.04 0.2 0.34 0.34 0.31 0.24 0.19 0.39 0.33 0.23 0.28 0.27 0.35 0.37 0.23 0.15 0.23 0.34 0.15 0.39 0.39 0.09 0.32 0.29 0.24 0.38 0.13 0.13 0.42 0.08 0.18 0.28 0.47 0.33 0.41 0.19 0.29 0.24;
        0.1 0.12 0.33 0.05 0.22 0.14 0.14 0.2 0.49 0.17 0.06 0.23 0.16 0.37 0.22 0.24 0.27 0.19 0.07 0.42 0.34 0.39 0.34 0.23 0.25 0.38 0.48 0.15 0.31 0 0.31 0.19 0.24 0.26 0.1 0.17 0.16 0.11 0.25 0.32;
        0.17 0.34 0.32 0.24 0.24 0.29 0.28 0.22 0.18 0.06 0.18 0.32 0.27 0.29 0.3 0.24 0.22 0.25 0.35 0.43 0.44 0.12 0.33 0.16 0.24 0.17 0.13 0.31 0.0 0.39 0.31 0.28 0.26 0.21 0.22 0.14 0.2 0.32 0.29 0.29;
    ])
    investment_data = IM.extra_inv_data(
        FixedProfile(1200), # capex [€/kW]
        FixedProfile(5e6), # FIX! # max installed capacity [kW]
        1e6, # 2e6, # FIX! existing capacity [kW]
        FixedProfile(2e6), # max_add [kW]
        FixedProfile(0), # min_add [kW]
        IM.ContinuousInvestment() # investment mode
    )
    wind = RP.NonDisRES("-den:wind", FixedProfile(2), wind_profile, 
        FixedProfile(500 * 1e-6), # var_opex [€/kW(12h)]
        FixedProfile(50), # fixed_opex [€/kW]
        Dict(Power=>1), 𝒫ᵉᵐ₀, Dict("InvestmentModels"=>investment_data))
    =#

    den_av = GEO.GeoAvailability("-den:av",  𝒫₀, 𝒫₀)
    den_area = GEO.Area("den", "Danmark", 56.0966, 8.2178, den_av)

    nodes = [den_av, sink, source] # wind]
    links = [
        EMB.Direct("den:src-av", nodes[3], nodes[1], EMB.Linear()),
        EMB.Direct("den:av-sink", nodes[1], nodes[2], EMB.Linear()),
        # EMB.Direct("d:snk-av", nodes[4], nodes[1], EMB.Linear())
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

    trm_line = GEO.RefStatic("cable", Power, 1e7, 0.05)
    transmissions = []
    areas = [den_area, nor_area, agd_area]
    
    for a1 in areas, a2 in areas
        a1 != a2 && push!(transmissions, GEO.Transmission(a1, a2, [trm_line]))
    end

    println(nodes)
    println(links)

    return Dict(
        :nodes=>nodes, 
        :links=>links, 
        :products=>[Power, NG, CO2], 
        :areas=>areas,
        :transmission=>transmissions, # [tr_nord_den, tr_den_nord], # tr_agder_nord]
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


prices = [0, 1000, 10000, 50000, 75000, 100000, 150000, 200000, 250000, 300000, 350000, 400000, 450000, 500000] #, 600000, 700000, 800000, 900000, 1000000]
investments = []

for var_opex_src in prices
    # var_opex_src is the price of production by the source in €/GWh
    data = get_data(var_opex_src)

    price = StrategicFixedProfile([50e-6, 60e-6, 70e-6, 80e-6])
    # price = FixedProfile(50e-6)
    case = IM.StrategicCase(StrategicFixedProfile([1e11, 1e11, 1e11, 1e11]),
        Dict(NG=>FixedProfile(0), CO2=>price))
    discount_rate = 0.07
    m = run_case_model(GLPK.Optimizer, data, case, discount_rate)

    println("=======================")
    println()
    source = data[:nodes][3]
    sink = data[:nodes][2]
    wind = data[:nodes][5]
    T = data[:T]
    println("pris ", var_opex_src * 1e-6, " €/kWh")
    println()
    println("source ", sum(value.(m[:cap_usage][source, t]) for t in T))
    println("sink ", sum(value.(m[:cap_usage][sink, t]) for t in T))
    println("wind ", sum(value.(m[:cap_usage][wind, t]) for t in T))
    println()
    @show value.(m[:add_cap])
    # @show value.(m[:flow_in])
    
    push!(investments, sum(value.(m[:add_cap][wind, t]) for t ∈ strategic_periods(T)))
end

println()
println(prices)
println(investments)
