
function run_model(fn, optimizer=nothing)
    @debug "Run model" fn optimizer

    # Build on the example used in energymodelsbase.jl
    case, modeltype = EMB.read_data(fn)

    CO2         = ResourceEmit("CO2", 1.)
    NG          = ResourceEmit("NG", 0.2)
    emissions   = Dict(CO2=>0.01, NG=>0)
    Power       = ResourceCarrier("Power", 1.)
    
    # Add a non-dispatchable renewable energy source to the system
    rs = NonDisRES(8, FixedProfile(2.), FixedProfile(1000), 
                   FixedProfile(10), Dict(Power=>1.))
    push!(case[:nodes], rs)

    # Link it to the Availability node
    d81 = Direct(81, case[:nodes][8], case[:nodes][1], Linear())
    push!(case[:links], d81)

    hydro = RegHydroStor(9, FixedProfile(2.),  FixedProfile(90), 
                         false, FixedProfile(10),
                         FixedProfile(1), FixedProfile(0.0), 
                         FixedProfile(3), Power, Dict(Power=>0.9), Dict(Power=>1), 
                         Dict())
    push!(case[:nodes], hydro)

    # Link it to the Availability node
    d91 = Direct(91, case[:nodes][9], case[:nodes][1], Linear())
    push!(case[:links], d91)
    
    return run_model(fn, optimizer, case, modeltype)
end

function run_model(fn, optimizer, case, modeltype)
    m = EMB.create_model(case, modeltype)

    if !isnothing(optimizer)
        set_optimizer(m, optimizer)
        optimize!(m)
        # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
        # TODO: save_solution(m) save results
    else
        @info "No optimizer given"
    end
    return m, case
end
