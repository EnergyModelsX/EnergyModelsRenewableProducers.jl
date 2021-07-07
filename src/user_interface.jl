
function run_model(fn, optimizer=nothing)
    @debug "Run model" fn optimizer

    # Build on the example used in energymodelsbase.jl
    data = EMB.read_data(fn)

    CO2 = ResourceEmit("CO2", 1.)
    NG = ResourceEmit("NG", 0.2)
    emissions = Dict(CO2=>0.01, NG=>0)
    Power = ResourceCarrier("Power", 1.)
    
    # Add a renewable energy source to the system
    rs = NonDispatchableRenewableEnergy(8, FixedProfile(2.), FixedProfile(1000), 
            FixedProfile(10), Dict(Power=>1.), emissions)
    push!(data[:nodes], rs)

    # Link it to the Availability node
    d81 = EMB.Direct(81, data[:nodes][8], data[:nodes][1], EMB.Linear())
    push!(data[:links], d81)

    case = EMB.OperationalCase(EMB.StrategicFixedProfile([450, 400, 350, 300]))    # 
    model = EMB.OperationalModel(case)
    m = EMB.create_model(data, model)

    if !isnothing(optimizer)
        set_optimizer(m, optimizer)
        optimize!(m)
        # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
        # TODO: save_solution(m) save results
    else
        @info "No optimizer given"
    end
    return 0
end
