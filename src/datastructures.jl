" A non-dispatchable renewable energy source."
struct NonDisRES <: EMB.Source
    id
    Cap::TimeProfile                    # Installed capacity.
    Profile::TimeProfile                # Power production profile as a ratio of the max capacity.
    Opex_var::TimeProfile               # Operational costs per GWh produced.
    Opex_fixed::TimeProfile             # Fixed operational costs
    Output::Dict{EMB.Resource, Real}    # Generated resources, normally Power
    Emissions::Dict{EMB.ResourceEmit, Real} # Emissions per GWh produced.
    Data::Dict{String, EMB.Data}        # Additional data (e.g. for investments)
end


" A regulated hydropower storage without pumping capabilities, modelled as a Source."
struct RegHydroStor <: EMB.Storage
    id
    Rate_cap::TimeProfile                    # Installed capacity.
    Stor_cap::TimeProfile               # Initial installed storage capacity in the dam.
    
    Has_pump::Bool
    Level_init::TimeProfile             # Initial energy stored in the dam, in units of power.
    Level_inflow::TimeProfile           # Inflow of power per operational period.
    Level_min::TimeProfile              # Minimum fraction of the reservoir capacity that can be left.
    
    Opex_var::TimeProfile               # Operational cost per GWh produced.
    Opex_fixed::TimeProfile             # Fixed operational costs
    Input::Dict{EMB.Resource, Real}     # Power used when pumping water into the reservoir.
    Output::Dict{EMB.Resource, Real}    # Power produced per operational period.
    Emissions::Dict{ResourceEmit, Real} # Emissions per GWh produced.
    Data::Dict{String, EMB.Data}        # Additional data (e.g. for investments)
end
