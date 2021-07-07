
struct NonDispatchableRenewableEnergy <: EMB.Source
    id
    capacity::TimeProfile
    profile::TimeProfile
    var_opex::TimeProfile
    output::Dict{EMB.Resource, Real}
    emissions::Dict{EMB.ResourceEmit, Real} # Emissions per kWh produced.
end
