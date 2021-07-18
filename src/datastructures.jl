" A non-dispatchable renewable energy source."
struct NonDispatchableRenewableEnergy <: EMB.Source
    id
    capacity::TimeProfile # Installed capacity, should be a Real.
    profile::TimeProfile # Power production profile as a ratio of the max capacity.
    var_opex::TimeProfile # Operational costs per GWh produced.
    output::Dict{EMB.Resource, Real}
    emissions::Dict{EMB.ResourceEmit, Real} # Emissions per GWh produced.
end


" A regulated hydropower storage without pumping capabilities, modelled as a Source."
struct RegulatedHydroStorage <: EMB.StorSource
    id
    capacity::TimeProfile # Installed capacity, should be a Real.
    
    has_pump::Bool
    init_reservoir::Real # Initial energy stored in the dam, in units of power.
    cap_reservoir::Real # Initial installed storage capacity in the dam.
    inflow::TimeProfile # Inflow of power per operational period.
    min_level::Real # Minimum fraction of the reservoir capacity that can be left.
    
    var_opex::TimeProfile # Operational cost per GWh produced.
    input::Dict{EMB.Resource, Real} # Power used when pumping water into the reservoir.
    output::Dict{EMB.Resource, Real} # Power produced per operational period.
    emissions::Dict{ResourceEmit, Real} # Emissions per GWh produced.
end
