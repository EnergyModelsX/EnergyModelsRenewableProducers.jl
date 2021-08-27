" A non-dispatchable renewable energy source."
struct NonDisRES <: EMB.Source
    id
    capacity::TimeProfile # Installed capacity, should be a Real.
    profile::TimeProfile # Power production profile as a ratio of the max capacity.
    var_opex::TimeProfile # Operational costs per GWh produced.
    fixed_opex::TimeProfile
    output::Dict{EMB.Resource, Real}
    emissions::Dict{EMB.ResourceEmit, Real} # Emissions per GWh produced.
    data::Dict{String, EMB.Data} # Additional data (e.g. for investments)
end


" A regulated hydropower storage without pumping capabilities, modelled as a Source."
struct RegHydroStor <: EMB.Storage
    id
    capacity::TimeProfile # Installed capacity, should be a Real.
    
    has_pump::Bool
    init_reservoir::TimeProfile # Initial energy stored in the dam, in units of power.
    cap_storage::Real # Initial installed storage capacity in the dam.
    inflow::TimeProfile # Inflow of power per operational period.
    min_level::TimeProfile # Minimum fraction of the reservoir capacity that can be left.
    
    var_opex::TimeProfile # Operational cost per GWh produced.
    fixed_opex::TimeProfile
    input::Dict{EMB.Resource, Real} # Power used when pumping water into the reservoir.
    output::Dict{EMB.Resource, Real} # Power produced per operational period.
    emissions::Dict{ResourceEmit, Real} # Emissions per GWh produced.
    data::Dict{String, EMB.Data} # Additional data (e.g. for investments)
end

Base.getindex(number::Number, i::TS.TimePeriod{UniformTwoLevel}) = number