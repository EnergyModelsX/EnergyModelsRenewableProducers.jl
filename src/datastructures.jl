""" A non-dispatchable renewable energy source.

# Fields
- **`id`** is the name/identifyer of the node.\n
- **`Cap::TimeProfile`** is the installed capacity.\n
- **`Profile::TimeProfile`** is the power production at each operational period as a ratio of the 
installed capacity at that time.\n
- **`Opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`Opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`Output::Dict{Resource, Real}`** are the generated `Resource`s, normally Power.\n
- **`Data::Array{Data}`** is the additional data (e.g. for investments).

"""
struct NonDisRES <: EMB.Source
    id::Any
    Cap::TimeProfile
    Profile::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Output::Dict{Resource,Real}
    Data::Array{Data}
end

""" An abstract type for hydro storage nodes, with or without pumping. """
abstract type HydroStorage <: EMB.Storage end

""" A regulated hydropower storage, modelled as a Storage node.

## Fields
- **`id`** is the name/identifyer of the node.\n
- **`Rate_cap::TimeProfile`**: installed capacity.\n
- **`Stor_cap::TimeProfile`** Initial installed storage capacity in the dam.\n
- **`Level_init::TimeProfile`** Initial energy stored in the dam, in units of power.\n
- **`Level_inflow::TimeProfile`** Inflow of power per operational period.\n
- **`Level_min::TimeProfile`** Minimum fraction of the reservoir capacity that can be left.\n
- **`Opex_var::TimeProfile`** Operational cost per GWh produced.\n
- **`Opex_fixed::TimeProfile`** Fixed operational costs.\n
- **`Stor_res::ResourceCarrier`** is the stored `Resource`.\n
- **`Input::Dict{Resource, Real}`** the stored and used resources. The
values in the Dict is a ratio describing the energy loss when using the pumps.\n
- **`Output::Dict{Resource, Real}`** can only contain one entry, the stored resource.\n
- **`Data::Array{Data}`** additional data (e.g. for investments).\n
"""
struct HydroStor <: HydroStorage
    id::Any
    Rate_cap::TimeProfile
    Stor_cap::TimeProfile

    Level_init::TimeProfile
    Level_inflow::TimeProfile
    Level_min::TimeProfile

    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Stor_res::ResourceCarrier
    Input::Dict{Resource,Real}
    Output::Dict{Resource,Real}
    Data::Array{Data}
end

""" A regulated hydropower storage with pumping capabilities, modelled as a Storage node.

## Fields
- **`id`** is the name/identifyer of the node.\n
- **`Rate_cap::TimeProfile`**: installed capacity.\n
- **`Stor_cap::TimeProfile`** Initial installed storage capacity in the dam.\n
- **`Level_init::TimeProfile`** Initial energy stored in the dam, in units of power.\n
- **`Level_inflow::TimeProfile`** Inflow of power per operational period.\n
- **`Level_min::TimeProfile`** Minimum fraction of the reservoir capacity that can be left.\n
- **`Opex_var::TimeProfile`** Operational cost per GWh produced.\n
- **`Opex_var_pump::TimeProfile`** Operational cost per GWh pumped into the reservoir.\n
- **`Opex_fixed::TimeProfile`** Fixed operational costs.\n
- **`Stor_res::ResourceCarrier`** is the stored `Resource`.\n
- **`Input::Dict{Resource, Real}`** the stored and used resources. The
values in the Dict is a ratio describing the energy loss when using the pumps.\n
- **`Output::Dict{Resource, Real}`** can only contain one entry, the stored resource.\n
- **`Data::Array{Data}`** additional data (e.g. for investments).\n
"""
struct PumpedHydroStor <: HydroStorage
    id::Any
    Rate_cap::TimeProfile
    Stor_cap::TimeProfile

    Level_init::TimeProfile
    Level_inflow::TimeProfile
    Level_min::TimeProfile

    Opex_var::TimeProfile
    Opex_var_pump::TimeProfile
    Opex_fixed::TimeProfile
    Stor_res::ResourceCarrier
    Input::Dict{Resource,Real}
    Output::Dict{Resource,Real}
    Data::Array{Data}
end

""" A constructor for a regulated hydropower storage, with or without pumping capabilities.

## Fields
- **`id`** is the name/identifyer of the node.\n
- **`Rate_cap::TimeProfile`**: installed capacity.\n
- **`Stor_cap::TimeProfile`** Initial installed storage capacity in the dam.\n
- **`Has_pump::Bool`** states wheter the stored resource can flow in.\n
- **`Level_init::TimeProfile`** Initial energy stored in the dam, in units of power.\n
- **`Level_inflow::TimeProfile`** Inflow of power per operational period.\n
- **`Level_min::TimeProfile`** Minimum fraction of the reservoir capacity that can be left.\n
- **`Opex_var::TimeProfile`** Operational cost per GWh produced.\n
- **`Opex_fixed::TimeProfile`** Fixed operational costs.\n
- **`Stor_res::ResourceCarrier`** is the stored `Resource`.\n
- **`Input::Dict{Resource, Real}`** the stored and used resources. The
values in the Dict is a ratio describing the energy loss when using the pumps.\n
- **`Output::Dict{Resource, Real}`** can only contain one entry, the stored resource.\n
- **`Data::Array{Data}`** additional data (e.g. for investments).\n
"""
function RegHydroStor(
    id::Any,
    Rate_cap::TimeProfile,
    Stor_cap::TimeProfile,
    Has_pump::Bool,
    Level_init::TimeProfile,
    Level_inflow::TimeProfile,
    Level_min::TimeProfile,
    Opex_var::TimeProfile,
    Opex_fixed::TimeProfile,
    Stor_res::ResourceCarrier,
    Input,
    Output,
    Data,
)
    if Has_pump
        return PumpedHydroStor(
            id,
            Rate_cap,
            Stor_cap,
            Level_init,
            Level_inflow,
            Level_min,
            FixedProfile(0),
            Opex_var,
            Opex_fixed,
            Stor_res,
            Input,
            Output,
            Data,
        )
    else
        return HydroStor(
            id,
            Rate_cap,
            Stor_cap,
            Level_init,
            Level_inflow,
            Level_min,
            FixedProfile(0),
            Opex_fixed,
            Stor_res,
            Input,
            Output,
            Data,
        )
    end
end
