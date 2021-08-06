const EMB = EnergyModelsBase
const RP = RenewableProducers


NG = ResourceEmit("NG", 0.2)
CO2 = ResourceEmit("CO2", 1.)
Power = ResourceCarrier("Power", 0.)
# Coal     = ResourceCarrier("Coal", 0.35)



function agder_nodes()
    max_storage = 100
    initial_reservoir = StrategicFixedProfile([20, 25, 20, 20])
    min_level = StrategicFixedProfile([0.1, 0.2, 0.1, 0.1])

    hydro = RP.RegHydroStor("-hydro", FixedProfile(10.), 
        true, initial_reservoir, max_storage, FixedProfile(1), min_level, 
        FixedProfile(30), FixedProfile(30), Dict(Power=>1), Dict(Power=>0.9), 
        Dict(CO2=>0.01, NG=>0))


    agder_av = Geography.GeoAvailability("-a-agder", Dict(Power=>1), Dict(Power=>1))
    agder_area = Geography.Area("agder", "Agder", 58.02722, 7.44889, agder_av)
        
    nodes = [agder_av, hydro] 
    links = [EMB.Direct("a:av-h", nodes[1], nodes[2], EMB.Linear()), 
             EMB.Direct("a:h-av", nodes[2], nodes[1], EMB.Linear())]

    return agder_area, agder_av, nodes, links 
end

function nord_nodes()
    # windprofile, snitt på 45%
    wind = RP.NonDisRES("-nwind", FixedProfile(2), FixedProfile(0.9), 
        FixedProfile(10), FixedProfile(10), Dict(Power=>1), Dict(CO2=>0.1, NG=>0))

    nords_av = Geography.GeoAvailability("-a-nord", Dict(Power=>1), Dict(Power=>1))
    nords_area = Geography.Area("nordsjøen", "Nordsjøen", 56.023, 3.164, nords_av)

    nodes = [nords_av, wind]
    links = [EMB.Direct("n:w-av", nodes[2], nodes[1], EMB.Linear())]

    return nords_area, nords_av, nodes, links
end


function denmark_nodes()

    # TODO add Source?

    wind = RP.NonDisRES("-dwind", FixedProfile(2), FixedProfile(0.9), 
        FixedProfile(10), FixedProfile(30), Dict(Power=>1), Dict(CO2=>0.1, NG=>0))

    den_av = Geography.GeoAvailability("-a-den", Dict(Power=>1), Dict(Power=>1))
    den_area = Geography.Area("den", "Danmark", 56.0966, 8.2178, den_av)

    nodes = [den_av, wind]
    links = [EMB.Direct("n:w-av", nodes[2], nodes[1], EMB.Linear())]
    
    return den_area, den_av, nodes, links
end


function get_data()
    agd_area, agd_av, agd_nodes, agd_links = agder_nodes()
    nor_area, nor_av, nor_nodes, nor_links = nord_nodes()
    # den_geo, den_av, den_nodes, den_links = den_nodes()
    den_area, den_av, den_nodes, den_links = denmark_nodes()
    # println("den_nodes res ", res)
    nodes = [agd_nodes..., nor_nodes..., den_nodes...]
    links = [agd_links..., nor_links..., den_links...]

    # Transmissions
    trm_agder_nord = Geography.RefStatic("a-n", Power, 10, 1)
    tr_agder_nord = Geography.Transmission(agd_area, nor_area, [trm_agder_nord])

    trm_den_nord = Geography.RefStatic("d-n", Power, 12, 1.2)
    tr_den_nord = Geography.Transmission(den_area, nor_area, [trm_den_nord])


    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))

    println(nodes)
    println(links)

    return Dict(:nodes=>nodes, :links=>links, :products=>[Power], :T=>T)
end



data = get_data()
m, data = RP.run_model("", GLPK.Optimizer, data)
solution_summary(m)
