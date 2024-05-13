""" A non-dispatchable renewable energy source.

# Fields
- **`id`** is the name/identifyer of the node.\n
- **`cap::TimeProfile`** is the installed capacity.\n
- **`profile::TimeProfile`** is the power production in each operational period as a ratio \
of the installed capacity at that time.\n
- **`opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`output::Dict{Resource, Real}`** are the generated `Resource`s, normally Power.\n
- **`data::Vector{Data}`** is the additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.

"""
struct NonDisRES <: EMB.Source
    id::Any
    cap::TimeProfile
    profile::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    output::Dict{<:Resource, <:Real}
    data::Vector{Data}
end
function NonDisRES(
        id::Any,
        cap::TimeProfile,
        profile::TimeProfile,
        opex_var::TimeProfile,
        opex_fixed::TimeProfile,
        output::Dict{<:Resource, <:Real},
    )
    return NonDisRES(id, cap, profile, opex_var, opex_fixed, output, Data[])
end

""" An abstract type for hydro storage nodes, with or without pumping. """
abstract type HydroStorage{T} <: EMB.Storage{T} end

""" A regulated hydropower storage, modelled as a `Storage` node.

## Fields
- **`id`** is the name/identifyer of the node.\n
- **`rate_cap::TimeProfile`**: installed capacity.\n
- **`stor_cap::TimeProfile`** Initial installed storage capacity in the dam.\n
- **`level_init::TimeProfile`** Initial energy stored in the dam, in units of power.\n
- **`level_inflow::TimeProfile`** Inflow of power per operational period.\n
- **`level_min::TimeProfile`** Minimum fraction of the reservoir capacity that can be left.\n
- **`stor_res::ResourceCarrier`** is the stored `Resource`.\n
- **`input::Dict{Resource, Real}`** the stored and used resources. The \
values in the Dict is a ratio describing the energy loss when using the pumps.\n
- **`output::Dict{Resource, Real}`** can only contain one entry, the stored resource.\n
- **`data::Vector{Data}`** additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.
"""
struct HydroStor{T} <: HydroStorage{T}
    id::Any
    level::EMB.UnionCapacity
    discharge::EMB.UnionCapacity

    level_init::TimeProfile
    level_inflow::TimeProfile
    level_min::TimeProfile

    stor_res::ResourceCarrier
    input::Dict{<:Resource, <:Real}
    output::Dict{<:Resource, <:Real}
    data::Vector{Data}
end
function HydroStor{T}(
        id::Any,
        level::EMB.UnionCapacity,
        discharge::EMB.UnionCapacity,
        level_init::TimeProfile,
        level_inflow::TimeProfile,
        level_min::TimeProfile,
        stor_res::ResourceCarrier,
        input::Dict{<:Resource, <:Real},
        output::Dict{<:Resource, <:Real},
    ) where {T<:EMB.StorageBehavior}
    return HydroStor{T}(
        id,
        level,
        discharge,
        level_init,
        level_inflow,
        level_min,
        stor_res,
        input,
        output,
        Data[],
    )
end

""" A regulated hydropower storage with pumping capabilities, modelled as a `Storage` node.

## Fields
- **`id`** is the name/identifyer of the node.\n
- **`rate_cap::TimeProfile`**: installed capacity.\n
- **`stor_cap::TimeProfile`** Initial installed storage capacity in the dam.\n
- **`level_init::TimeProfile`** Initial energy stored in the dam, in units of power.\n
- **`level_inflow::TimeProfile`** Inflow of power per operational period.\n
- **`level_min::TimeProfile`** Minimum fraction of the reservoir capacity that can be left.\n
- **`stor_res::ResourceCarrier`** is the stored `Resource`.\n
- **`input::Dict{Resource, Real}`** the stored and used resources. The \
values in the Dict is a ratio describing the energy loss when using the pumps.\n
- **`output::Dict{Resource, Real}`** can only contain one entry, the stored resource.\n
- **`data::Vector{Data}`** additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.\n
"""
struct PumpedHydroStor{T} <: HydroStorage{T}
    id::Any
    charge::EMB.UnionCapacity
    level::EMB.UnionCapacity
    discharge::EMB.UnionCapacity

    level_init::TimeProfile
    level_inflow::TimeProfile
    level_min::TimeProfile

    stor_res::ResourceCarrier
    input::Dict{<:Resource, <:Real}
    output::Dict{<:Resource, <:Real}
    data::Vector{Data}
end
function PumpedHydroStor{T}(
        id::Any,
        charge::EMB.UnionCapacity,
        level::EMB.UnionCapacity,
        discharge::EMB.UnionCapacity,
        level_init::TimeProfile,
        level_inflow::TimeProfile,
        level_min::TimeProfile,
        stor_res::ResourceCarrier,
        input::Dict{<:Resource, <:Real},
        output::Dict{<:Resource, <:Real},
    ) where {T<:EMB.StorageBehavior}
    return PumpedHydroStor{T}(
        id,
        charge,
        level,
        discharge,
        level_init,
        level_inflow,
        level_min,
        stor_res,
        input,
        output,
        Data[],
    )
end

"""
    profile(n::NonDisRES, t)

Returns the profile of a node `n` of type `NonDisRES` at operational period `t`.
"""
profile(n::NonDisRES, t) = n.profile[t]

"""
    level_init(n::HydroStorage, t)

Returns the innitial level of a node `n` of type `HydroStorage` at operational period `t`
"""
level_init(n::HydroStorage, t) = n.level_init[t]

"""
    level_inflow(n::HydroStorage, t)

Returns the inflow to a node `n` of type `HydroStorage` at operational period `t`
"""
level_inflow(n::HydroStorage, t) = n.level_inflow[t]

"""
    level_min(n::HydroStorage, t)

Returns the minimum level of a node `n` of type `HydroStorage` at operational period `t`
"""
level_min(n::HydroStorage, t) = n.level_min[t]

"""
    opex_var_pump(n::PumpedHydroStor, t)

Returns the variable OPEX of a node `n` of type `PumpedHydroStor` related to pumping at
operational period `t`
"""
opex_var_pump(n::PumpedHydroStor, t) = n.opex_var_pump[t]
