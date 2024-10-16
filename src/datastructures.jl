"""
    NonDisRES <: EMB.Source

A non-dispatchable renewable energy source. It extends the existing `RefSource` node through
including a profile that corresponds to thr production. The profile can have variations on
the strategic level.

# Fields
- **`id`** is the name/identifyer of the node.
- **`cap::TimeProfile`** is the installed capacity.
- **`profile::TimeProfile`** is the power production in each operational period as a ratio
  of the installed capacity at that time.
- **`opex_var::TimeProfile`** is the variable operating expense per energy unit produced.
- **`opex_fixed::TimeProfile`** is the fixed operating expense.
- **`output::Dict{Resource, Real}`** are the generated `Resource`s, normally Power.
- **`data::Vector{Data}`** is the additional data (e.g. for investments). The field `data`
  is conditional through usage of a constructor.
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

"""
    profile(n::NonDisRES)
    profile(n::NonDisRES, t)

Returns the profile of a node `n` of type `NonDisRES` either as `TimeProfile` or at
operational period `t`.
"""
profile(n::NonDisRES) = n.profile
profile(n::NonDisRES, t) = n.profile[t]

""" An abstract type for hydro storage nodes, with or without pumping. """
abstract type HydroStorage{T} <: EMB.Storage{T} end

"""
    HydroStor{T} <: HydroStorage{T}

A regulated hydropower storage, modelled as a `Storage` node. A regulated hydro storage node
requires a capacity for the `discharge` and does not have a required inflow from the model,
except for water inflow from outside the model, although it requires a field `input`.

## Fields
- **`id`** is the name/identifyer of the node.
- **`level::EMB.UnionCapacity`** are the level parameters of the `HydroStor` node.
  Depending on the chosen type, the charge parameters can include variable OPEX and/or fixed OPEX.
- **`discharge::EMB.UnionCapacity`** are the discharging parameters of the `HydroStor` node.
  Depending on the chosen type, the discharge parameters can include variable OPEX, fixed OPEX,
  and/or a capacity.
- **`level_init::TimeProfile`** is the initial stored energy in the dam.
- **`level_inflow::TimeProfile`** is the inflow of power per operational period.
- **`level_min::TimeProfile`** is the minimum fraction of the reservoir capacity that
  has to remain in the `HydroStorage` node.
- **`stor_res::ResourceCarrier`** is the stored `Resource`.
- **`input::Dict{Resource, Real}`** are the input `Resource`s. In the case of a `HydroStor`,
  this field can be left out.
- **`output::Dict{Resource, Real}`** can only contain one entry, the stored resource.
- **`data::Vector{Data}`** additional data (e.g. for investments). The field `data` is
  conditional through usage of a constructor.
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
        output::Dict{<:Resource, <:Real},
        data::Vector{Data},
    ) where {T<:EMB.StorageBehavior}
    return HydroStor{T}(
        id,
        level,
        discharge,
        level_init,
        level_inflow,
        level_min,
        stor_res,
        Dict{Resource,Real}(stor_res => 1),
        output,
        data,
    )
end
function HydroStor{T}(
        id::Any,
        level::EMB.UnionCapacity,
        discharge::EMB.UnionCapacity,

        level_init::TimeProfile,
        level_inflow::TimeProfile,
        level_min::TimeProfile,

        stor_res::ResourceCarrier,
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
        Dict{Resource,Real}(stor_res => 1),
        output,
        Data[],
    )
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

"""
    PumpedHydroStor{T} <: HydroStorage{T}

A pumped hydropower storage, modelled as a `Storage` node. A pumped hydro storage node
allows for storing energy through pumping water into the reservoir. The current
implementation is a simplified node in which no lower reservoir is required. Instead, it is
assumed that the reservoir has an infinite size.

A pumped hydro storage node requires a capacity for both `charge` and `discharge` to
account for the potential to store energy in the form of potential energy.

## Fields
- **`id`** is the name/identifyer of the node.
- **`charge::EMB.UnionCapacity`** are the charging parameters of the `PumpedHydroStor` node.
  Depending on the chosen type, the charge parameters can include variable OPEX, fixed OPEX,
  and/or a capacity.
- **`level::EMB.UnionCapacity`** are the level parameters of the `HydroStor` node.
  Depending on the chosen type, the charge parameters can include variable OPEX and/or fixed OPEX.
- **`discharge::EMB.UnionCapacity`** are the discharging parameters of the `HydroStor` node.
  Depending on the chosen type, the discharge parameters can include variable OPEX, fixed OPEX,
  and/or a capacity.
- **`level_init::TimeProfile`** is the initial stored energy in the dam.
- **`level_inflow::TimeProfile`** is the inflow of power per operational period.
- **`level_min::TimeProfile`** is the minimum fraction of the reservoir capacity that
  has to remain in the `HydroStorage` node.
- **`stor_res::ResourceCarrier`** is the stored `Resource`.
- **`input::Dict{Resource, Real}`** are the input `Resource`s.
- **`output::Dict{Resource, Real}`** can only contain one entry, the stored resource.
- **`data::Vector{Data}`** additional data (e.g. for investments). The field `data` is
  conditional through usage of a constructor.
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
    level_init(n::HydroStorage)
    level_init(n::HydroStorage, t)

Returns the initial level of a node `n` of type `HydroStorage` either as `TimeProfile` or at
operational period `t`.
"""
level_init(n::HydroStorage) = n.level_init
level_init(n::HydroStorage, t) = n.level_init[t]

"""
    level_inflow(n::HydroStorage)
    level_inflow(n::HydroStorage, t)

Returns the inflow to a node `n` of type `HydroStorage` either as `TimeProfile` or at
operational period `t`.
"""
level_inflow(n::HydroStorage) = n.level_inflow
level_inflow(n::HydroStorage, t) = n.level_inflow[t]

"""
    level_min(n::HydroStorage)
    level_min(n::HydroStorage, t)

Returns the minimum level of a node `n` of type `HydroStorage` either as `TimeProfile` or at
operational period `t`.
"""
level_min(n::HydroStorage) = n.level_min
level_min(n::HydroStorage, t) = n.level_min[t]

"""
    opex_var_pump(n::PumpedHydroStor)
    opex_var_pump(n::PumpedHydroStor, t)

Returns the variable OPEX of a node `n` of type `PumpedHydroStor` related to pumping either
as `TimeProfile` or at operational period `t`.
"""
opex_var_pump(n::PumpedHydroStor) = n.opex_var_pump
opex_var_pump(n::PumpedHydroStor, t) = n.opex_var_pump[t]

abstract type AbstractMinMaxConstraint <: EMB.Data end
# struct NoConstraint <: AbstractMinMaxConstraint end
struct MinConstraint <: AbstractMinMaxConstraint
    name::Symbol
    value::TS.TimeProfile{<:Number}
    flag::TS.TimeProfile{Bool}
    penalty::TS.TimeProfile{<:Number}
end
struct MaxConstraint <: AbstractMinMaxConstraint
    name::Symbol
    value::TimeProfile
    flag::TS.TimeProfile{Bool}
    penalty::TS.TimeProfile{<:Number}
end
struct ScheduleConstraint <: AbstractMinMaxConstraint
    name::Symbol
    value::TimeProfile
    flag::TS.TimeProfile{Bool}
    penalty::TS.TimeProfile{<:Number}
end
is_constraint_data(data::Data) = (typeof(data) <: AbstractMinMaxConstraint)
is_active(s::AbstractMinMaxConstraint, t) = s.flag[t]
value(s::AbstractMinMaxConstraint, t) = s.value[t]
has_penalty(s::AbstractMinMaxConstraint, t) = !isinf(s.penalty[t])
has_penalty_up(data::AbstractMinMaxConstraint) = (typeof(data) <: Union{MinConstraint, ScheduleConstraint})
has_penalty_up(data::AbstractMinMaxConstraint, t) = has_penalty_up(data) & has_penalty(data, t)
has_penalty_down(data::AbstractMinMaxConstraint) = (typeof(data) <: Union{MaxConstraint, ScheduleConstraint})
has_penalty_down(data::AbstractMinMaxConstraint, t) = has_penalty_down(data) & has_penalty(data, t)
function get_penalty_up_time(data::Vector{<:Data}, 𝒯)
    return [t for t in 𝒯 if any(has_penalty_up(c, t) for c in data)]
end
function get_penalty_down_time(data::Vector{<:Data}, 𝒯)
    return [t for t in 𝒯 if any(has_penalty_down(c, t) for c in data)]
end

penalty(s::AbstractMinMaxConstraint, t) = s.penalty[t]

""" A regulated hydropower reservoir, modelled as a `Storage` node.

## Fields
- **`id`** is the name/identifyer of the node.\n
- **`vol::EMB.UnionCapacity`** are the storage volume parameters of the HydroReservoir node.
- **`vol_inflow::TimeProfile`** is the inflow to the reservoir.
- **`vol_init::TimeProfile`** is the initial stored water in the reservoir.
- **`vol_min::TimeProfile`** is the minimum storage limit for the reservoir.
- **`vol_max::TimeProfile`** is the maximum storage limit for the reservoir.
- **`vol_level::Dict{<:Real, <:Real}`** is the relation between stored volume of water in the reservoir and level.
- **`stor_res::ResourceCarrier`** is the stored `Resource`.\n
- **`input::Dict{Resource, Real}`** the stored and used resources.\n
- **`output::Dict{Resource, Real}`** can only contain one entry, the stored resource.\n
- **`data::Vector{Data}`** additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.
"""

struct HydroReservoir{T} <: EMB.Storage{T}
    id::Any
    vol::EMB.UnionCapacity
    vol_inflow::TimeProfile
    # vol_init::TimeProfile
    # vol_constraint::AbstractMinMaxConstraint
    # vol_min::TimeProfile
    # vol_max::TimeProfile
    # penalty_cost::Dict{Symbol, TimeProfile}
    # TODO Not yet implemented
    # vol_level::Dict{<:Real, <:Real}
    # level_init::TimeProfile#
    # level_inflow::TimeProfile
    # level_min::TimeProfile # Lowest permitted regulated water level
    # level_max::TimeProfile # Highest permitted regulated water level
    #water_value::Dict{<: Int, <:Dict{<:Real, <:Real}} # linear constraints binding the value of the storage
    stor_res::ResourceCarrier # Water
    input::Dict{<:Resource,<:Real} # Water
    output::Dict{<:Resource,<:Real} # Water
    data::Vector{Data}
end
function HydroReservoir{T}(
    id::Any,
    vol::EMB.UnionCapacity,
    vol_inflow::TimeProfile,
    # vol_init::TimeProfile,
    # vol_constraint::AbstractMinMaxConstraint,
    # vol_min::TimeProfile,
    # vol_max::TimeProfile,
    # TODO not yet implemented
    # vol_level::Dict{<:Real, <:Real}
    # level_init::TimeProfile#
    # level_inflow::TimeProfile
    # level_min::TimeProfile,
    # level_max::TimeProfile,
    #water_value::Union{<:Real, <:Real},
    stor_res::ResourceCarrier,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real}
    ) where {T<:EMB.StorageBehavior}
    return HydroReservoir{T}(
        id,
        vol,
        vol_inflow,
        # vol_init,
        # vol_constraint,
        # vol_min,
        # vol_max,
        stor_res,
        input,
        output,
        Data[],
    )
end

"""
    level(n::HydroReservoir)

Returns the parameter type of the `vol` field of the node.
"""
EMB.level(n::HydroReservoir) = n.vol
EMB.level(n::HydroReservoir, t) = n.vol[t]


""" A Hydro Gate, modelled as a `NetworkNode` node. Can be used to model outlets/inlets and
minimum/maximum requirements for water flow.

## Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** is the installed discharge capacity.
- **`opex_var::TimeProfile`** is the variational operational costs per energy unit produced.
- **`opex_fixed::TimeProfile`** is the fixed operational costs.
- **`input::Dict{<:Resource, <:Real}`** are the input `Resource`s with conversion value `Real`.
- **`output::Dict{<:Resource, <:Real}`** are the generated `Resource`s with conversion value `Real`.
- **`data::Vector{Data}`** is the additional data (e.g. for investments). The field
  `data` is conditional through usage of a constructor.
"""
#TODO add option for maximum and minimum requirement

struct HydroGate <: EMB.NetworkNode
    id::Any
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    input::Dict{<:Resource,<:Real}
    output::Dict{<:Resource,<:Real}
    data::Vector{Data}
end
function HydroGate(
    id::Any,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
)
    return HydroGate(id, cap, opex_var, opex_fixed, input, output, Data[])
end

""" A regular hydropower plant, modelled as a `NetworkNode` node.

## Fields
- **`id`** is the name/identifier of the node.\n
- **`cap::TimeProfile`** is the installed discharge capacity.\n
- **`pq_curve::Dict{<:Resource, <:Vector{<:Real}}` describes the relationship between power and discharge (water).\
requires one input resource (usually Water) and two output resources (usually Water and Power) to be defined \
where the input resource also is an output resource. \n
- **`opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`input::Dict{<:Resource, <:Real}`** are the input `Resource`s with conversion value `Real`.\n
- **`output::Dict{<:Resource, <:Real}`** are the generated `Resource`s with conversion value `Real`.\n
- **`data::Vector{Data}`** is the additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.
"""

struct HydroGenerator <: EMB.NetworkNode # plant or pump or both?
    id::Any
    #power_cap::TimeProfile # maximum production MW/(time unit)
    cap::TimeProfile # maximum discharge mm3/(time unit)
    pq_curve::Union{Dict{<:Resource, <:Vector{<:Real}}, Nothing}# Production and discharge ratio [MW / m3/s]
    #pump_power_cap::TimeProfile #maximum production MW
    #pump_disch_cap::TimeProfile #maximum discharge mm3/time unit
    #pump_pq_curve::Dict{<:Real, <:Real}
    #prod_min::TimeProfile # Minimum production [MW]
    #prod_max::TimeProfile # Maximum production [MW]
    #cons_min::TimeProfile # Minimum consumption [MW]
    #cons_max::TimeProfile # Maximum consumption [MW]
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    input::Dict{<:Resource,<:Real}
    output::Dict{<:Resource,<:Real}
    η::Vector{Real} # PQ_curve: production and discharge ratio [MW / m3/s]
    data::Vector{Data}
end
function HydroGenerator(
    id::Any,
    #power_cap::TimeProfile,
    cap::TimeProfile,
    #pq_curve::Dict{<:Real, <:Real},
    #pump_power_cap::TimeProfile,
    #pump_disch_cap::TimeProfile,
    #pump_pq_curve::Dict{<:Real, <:Real},
    #prod_min::TimeProfile,
    #prod_max::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real};
    pq_curve::AbstractPqCurve,
    #η = Real[],
)

    return HydroGenerator(id, cap, pq_curve, opex_var, opex_fixed, input, output, η, Data[])
end

abstract type AbstractPqCurve <: EMB.Data end

# struct NoPqCurve <: AbstractPqCurve end # Do we need this to enable modelling as energy only (not conversion from water to energy)?

# do we need this or can we use existing functionality in outputs?
struct EnergyEquivalent <: AbstractPqCurve
    name::Symbol
    value::Real # MW / m3/s
end

struct PqCurve <: AbstractPqCurve
    name::Symbol
    value::Vecor{Real}  # MW / m3/s
    DischargeBreakpoints::Vecor{Real} #share of total discharege capacity (0,1)
end

#struct PqCurveHeadDependen <: AbstractPqCurve
#    name::Symbol
#    value::Real
#end



"""
    pq_curve(n::HydroGenerator)

Returns the resources in the PQ-curve of a node `n` of type `HydroGenerator`
"""
function pq_curve(n::HydroGenerator)
    if !isnothing(n.pq_curve)
        return collect(keys(n.pq_curve))
    else
        return nothing
    end
end

"""
    pq_curve(n::HydroGenerator, p)

Returns the values in the pq_curve for resurce p of a node `n` of type `HydroGenerator`
"""
function pq_curve(n::HydroGenerator, p::Resource)

    if !isnothing(n.pq_curve)
        return  n.pq_curve[p]
    else
        return nothing
    end

end
"""
    efficiency(n::HydroGenerator)

Returns vector of the efficiency segments a node `n` of type `HydroGenerator`
"""
efficiency(n::HydroGenerator) = n.η


# TODO make pump module