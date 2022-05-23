""" A non-dispatchable renewable energy source.


# Fields

**`id`**

**`Cap`** is the installed capacity as a `TimeProfile`.

**`Profile`** is the power production at each operational period as a ratio of the 
installed capacity at that time.

**`Opex_var`** is the variational operational costs.

**`Opex_fixed`** is the fixed operational costs.

**`Output`**

**`Emissions`**

**`Data`**

"""
struct NonDisRES <: EMB.Source
    id
    "Installed capacity"
    Cap::TimeProfile                    # Installed capacity.
    Profile::TimeProfile                # Power production profile as a ratio of the max capacity.
    Opex_var::TimeProfile               # Operational costs per GWh produced.
    Opex_fixed::TimeProfile             # Fixed operational costs
    Output::Dict{EMB.Resource, Real}    # Generated resources, normally Power
    Emissions::Dict{EMB.ResourceEmit, Real} # Emissions per GWh produced.
    Data::Dict{String, EMB.Data}        # Additional data (e.g. for investments)
end


""" A regulated hydropower storage with pumping capabilities, modelled as a Storage node.

## Fields

**`id`**

**`Rate_cap`**

**`Stor_cap`**

**`Has_pump::Bool`** states wheter the stored resource can flow in.

**`Level_init`**

**`Level_inflow`**

**`Level_min`**

**`Opex_var`**

**`Opex_fixed`**

**`Input::Dict`** the stored and used resources.

**`Output::Dict`** can only contain one entry, and states the stored resource.

**`Emissions`**

**`Data`**
"""
struct RegHydroStor <: EMB.Storage
    id
    Rate_cap::TimeProfile               # Installed capacity.
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
