const EMB = EnergyModelsBase
const GEO = Geography
const IM = InvestmentModels
const RP = RenewableProducers

NG = ResourceEmit("NG", 0.2)
CO2 = ResourceEmit("CO2", 1.)
Power = ResourceCarrier("Power", 0.)
Coal     = ResourceCarrier("Coal", 0.35)



function agder_nodes()
    max_storage = 100
    initial_reservoir = StrategicFixedProfile([20, 25, 20, 20])
    min_level = StrategicFixedProfile([0.1, 0.2, 0.1, 0.1])

    investment_data = IM.extra_inv_data(
        FixedProfile(2700), # EUR/kW
        FixedProfile(10), # FIX
        10,
        FixedProfile(10),
        FixedProfile(10),
        IM.ContinuousInvestment()
    )
    hydro = RP.RegHydroStor("-hydro", FixedProfile(10.), 
        true, initial_reservoir, max_storage, FixedProfile(1), min_level, 
        FixedProfile(30), FixedProfile(30), Dict(Power=>1), Dict(Power=>0.9), 
        Dict(CO2=>0.01, NG=>0), Dict("InvestmentModels"=>investment_data))

    agder_av = Geography.GeoAvailability("-a-agder", Dict(Power=>1), Dict(Power=>1))
    agder_area = Geography.Area("agder", "Agder", 58.02722, 7.44889, agder_av)
        
    nodes = [agder_av, hydro] 
    links = [EMB.Direct("a:av-h", nodes[1], nodes[2], EMB.Linear()), 
             EMB.Direct("a:h-av", nodes[2], nodes[1], EMB.Linear())]

    return agder_area, agder_av, nodes, links 
end

function nord_nodes()
    # windprofile, snitt på 45%

    # Mean=0.45, std=0.1. TODO create a NormalDistProfile(mean, std, 𝒯, seed)?
    profile = DynamicProfile([
        0.27 0.54 0.57 0.42;# 0.46 0.35 0.43 0.33 0.4 0.49 0.39 0.42 0.43 0.44 0.48 0.4 0.57 0.33 0.49 0.44 0.41 0.45 0.49 0.69 0.51 0.37 0.34 0.42 0.47 0.43 0.42 0.37 0.4 0.35 0.48 0.67 0.5 0.33 0.46 0.37;
        0.3 0.56 0.24 0.49;# 0.35 0.32 0.22 0.35 0.45 0.48 0.33 0.62 0.53 0.38 0.46 0.4 0.38 0.39 0.3 0.49 0.54 0.23 0.42 0.5 0.31 0.54 0.43 0.51 0.43 0.35 0.63 0.35 0.38 0.31 0.25 0.33 0.47 0.28 0.42 0.38;
        0.35 0.59 0.5 0.69;# 0.23 0.39 0.41 0.48 0.31 0.45 0.34 0.43 0.26 0.59 0.38 0.44 0.52 0.39 0.41 0.48 0.49 0.33 0.29 0.44 0.63 0.51 0.6 0.45 0.58 0.42 0.48 0.55 0.39 0.38 0.5 0.32 0.42 0.47 0.42 0.56;
        0.51 0.49 0.45 0.45;# 0.48 0.38 0.38 0.46 0.45 0.5 0.29 0.45 0.32 0.56 0.43 0.59 0.52 0.47 0.3 0.47 0.39 0.35 0.26 0.31 0.49 0.45 0.36 0.46 0.49 0.31 0.34 0.38 0.51 0.52 0.54 0.4 0.43 0.55 0.54 0.37;
    ])

    investment_data = IM.extra_inv_data(
        FixedProfile(2700), # capex [€/kW]
        FixedProfile(1e10), # FIX # max installed capacity [kW]
        1e6, # existing capacity [kW]
        FixedProfile(5e6), # max_add [kW]
        FixedProfile(0), # min_add [kW]
        IM.ContinuousInvestment() # investment mode
    )
    wind = RP.NonDisRES("-nwind", FixedProfile(2), profile,
        FixedProfile(1000 * 12 * 1e-6), # var_opex [€/kW(12h)]
        FixedProfile(100), # fixed_opex [€/kW]
        Dict(Power=>1), Dict(CO2=>0.1, NG=>0), Dict("InvestmentModels"=>investment_data))

    nords_av = GEO.GeoAvailability("-a-nord", Dict(Power=>1), Dict(Power=>1))
    nords_area = GEO.Area("nordsjøen", "Nordsjøen", 56.023, 3.164, nords_av)

    nodes = [nords_av, wind]
    links = [EMB.Direct("n:w-av", nodes[2], nodes[1], EMB.Linear())]

    return nords_area, nords_av, nodes, links
end


function denmark_nodes()

    # TODO add Source? FixedStrategic for source. Sink: mindre om natten enn dagen, mer om vinter enn om dagen
    # source, sink

    investment_data_source = IM.extra_inv_data(
        FixedProfile(1200), # capex [€/kW]
        FixedProfile(1e10), # FIX! # max installed capacity [kW]
        1e6, # FIX! existing capacity [kW]
        FixedProfile(0), # max_add [kW]
        FixedProfile(0), # min_add [kW]
        IM.ContinuousInvestment() # investment mode
    )
    source = EMB.RefSource("-dsource", FixedProfile(2e6), # id, capacity
        FixedProfile(500), # var_opex
        FixedProfile(100), # fixed_opex
        Dict(Power=>1), # output
        Dict(CO2=>1, NG => 0.1), # emissions
        Dict("InvestmentModels"=>investment_data_source)
    )

    sink = EMB.RefSink("-dsink", FixedProfile(30), # id, capacity
        Dict(:surplus=>0, :deficit=>1e6), # penalty 
        Dict(Power => 1), # input
        Dict(CO2 => 1, NG => 0.2), # emissions 
    )

    # Mean=0.25, std=0.1
    wind_profile = DynamicProfile([
        0.05 0.2 0.24 0.31; # 0.24 0.23 0.26 0.14 0.41 0.22 0.05 0.25 0.23 0.2 0.14 0.23 0.33 0.3 0.31 0.33 0.26 0.23 0.17 0.31 0.35 0.18 0.34 0.16 0.14 0.32 0.42 0.16 0.07 0.14 0.39 0.52 0.34 0.22 0.35 0.07;
        0.05 0.21 0.04 0.2; # 0.34 0.34 0.31 0.24 0.19 0.39 0.33 0.23 0.28 0.27 0.35 0.37 0.23 0.15 0.23 0.34 0.15 0.39 0.39 0.09 0.32 0.29 0.24 0.38 0.13 0.13 0.42 0.08 0.18 0.28 0.47 0.33 0.41 0.19 0.29 0.24;
        0.1 0.12 0.33 0.05;# 0.22 0.14 0.14 0.2 0.49 0.17 0.06 0.23 0.16 0.37 0.22 0.24 0.27 0.19 0.07 0.42 0.34 0.39 0.34 0.23 0.25 0.38 0.48 0.15 0.31 0 0.31 0.19 0.24 0.26 0.1 0.17 0.16 0.11 0.25 0.32;
        0.17 0.34 0.32 0.24;# 0.24 0.29 0.28 0.22 0.18 0.06 0.18 0.32 0.27 0.29 0.3 0.24 0.22 0.25 0.35 0.43 0.44 0.12 0.33 0.16 0.24 0.17 0.13 0.31 0.0 0.39 0.31 0.28 0.26 0.21 0.22 0.14 0.2 0.32 0.29 0.29;
    ])
    investment_data = IM.extra_inv_data(
        FixedProfile(1200), # capex [€/kW]
        FixedProfile(1e10), # FIX! # max installed capacity [kW]
        2e6, # FIX! existing capacity [kW]
        FixedProfile(5e6), # max_add [kW]
        FixedProfile(0), # min_add [kW]
        IM.ContinuousInvestment() # investment mode
    )
    wind = RP.NonDisRES("-dwind", FixedProfile(2), wind_profile, 
        FixedProfile(500 * 1e-6), # var_opex [€/kW(12h)]
        FixedProfile(50), # fixed_opex [€/kW]
        Dict(Power=>1), Dict(CO2=>0, NG=>0), Dict("InvestmentModels"=>investment_data))

    den_av = GEO.GeoAvailability("-a-den", Dict(Power=>1), Dict(Power=>1))
    den_area = GEO.Area("den", "Danmark", 56.0966, 8.2178, den_av)

    nodes = [den_av, wind, source, sink]
    links = [
        EMB.Direct("d:w-av", nodes[2], nodes[1], EMB.Linear()),
        EMB.Direct("d:src-av", nodes[3], nodes[1], EMB.Linear()),
        EMB.Direct("d:snk-av", nodes[1], nodes[4], EMB.Linear())
    ]
    
    return den_area, den_av, nodes, links
end


function get_data()
    agd_area, agd_av, agd_nodes, agd_links = agder_nodes()
    nor_area, nor_av, nor_nodes, nor_links = nord_nodes()
    den_area, den_av, den_nodes, den_links = denmark_nodes()

    nodes = [den_nodes..., nor_nodes...] #agd_nodes...]
    links = [den_links..., nor_links...] # agd_links...]

    # Transmissions
    trm_agder_nord = GEO.RefStatic("a-n", Power, 100, 0)
    tr_agder_nord = GEO.Transmission(agd_area, nor_area, [trm_agder_nord])

    trm_den_nord = GEO.RefStatic("d-n", Power, 100, 0)
    tr_den_nord = GEO.Transmission(den_area, nor_area, [trm_den_nord])

    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 4, 1))

    println(nodes)
    println(links)

    return Dict(
        :nodes=>nodes, 
        :links=>links, 
        :products=>[Power], 
        :areas=>[nor_area, den_area], # agd_area]
        :transmission=>[tr_den_nord], # tr_agder_nord]
        :T=>T)
end


function run_case_model(optimizer, data)
    # case = EMB.OperationalCase(EMB.StrategicFixedProfile([450, 400, 350, 300]))
    # model = EMB.OperationalModel(case)

    case = IM.StrategicCase(StrategicFixedProfile([450, 400, 350, 300]))
    discount_rate = 4
    model = IM.InvestmentModel(case, discount_rate)
    
    # case = EMB.OperationalCase(EMB.StrategicFixedProfile([450, 400, 350, 300]))    # 
    # model = EMB.OperationalModel(case)
    
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


data = get_data()
m = run_case_model(GLPK.Optimizer, data)
println(solution_summary(m))

# println(value.(m[:trans_out]))