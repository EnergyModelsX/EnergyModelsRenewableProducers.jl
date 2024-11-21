"""
    abstract type AbstractNonDisRES <: EMB.Source

Abstract supertype for all non-dispatchable renewable energy source. All functions for the
implemented version of the [`NonDisRES`](@ref) are dispatching on this supertype.
"""
abstract type AbstractNonDisRES <: EMB.Source end
"""
    NonDisRES <: AbstractNonDisRES

A non-dispatchable renewable energy source. It extends the existing `RefSource` node through
including a profile that corresponds to the production. The profile can have variations on
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
struct NonDisRES <: AbstractNonDisRES
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
    profile(n::AbstractNonDisRES)
    profile(n::AbstractNonDisRES, t)

Returns the profile of a node `n` of type `AbstractNonDisRES` either as `TimeProfile` or in
operational period `t`.
"""
profile(n::AbstractNonDisRES) = n.profile
profile(n::AbstractNonDisRES, t) = n.profile[t]

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

Returns the initial level of a node `n` of type `HydroStorage` either as `TimeProfile` or in
operational period `t`.
"""
level_init(n::HydroStorage) = n.level_init
level_init(n::HydroStorage, t) = n.level_init[t]

"""
    level_inflow(n::HydroStorage)
    level_inflow(n::HydroStorage, t)

Returns the inflow to a node `n` of type `HydroStorage` either as `TimeProfile` or in
operational period `t`.
"""
level_inflow(n::HydroStorage) = n.level_inflow
level_inflow(n::HydroStorage, t) = n.level_inflow[t]

"""
    level_min(n::HydroStorage)
    level_min(n::HydroStorage, t)

Returns the minimum level of a node `n` of type `HydroStorage` either as `TimeProfile` or in
operational period `t`.
"""
level_min(n::HydroStorage) = n.level_min
level_min(n::HydroStorage, t) = n.level_min[t]

"""
    opex_var_pump(n::PumpedHydroStor)
    opex_var_pump(n::PumpedHydroStor, t)

Returns the variable OPEX of a node `n` of type `PumpedHydroStor` related to pumping either
as `TimeProfile` or in operational period `t`.
"""
opex_var_pump(n::PumpedHydroStor) = n.opex_var_pump
opex_var_pump(n::PumpedHydroStor, t) = n.opex_var_pump[t]

"""
    abstract type AbstractScheduleType

Abstract supertype for the different constraint types.
"""
abstract type AbstractScheduleType end

"""
    abstract type MinSchedule <: AbstractScheduleType

Abstract type used to define a `ScheduleConstraint` as a minimum constraint.
"""
abstract type MinSchedule <: AbstractScheduleType end

"""
    abstract type MaxSchedule <: AbstractScheduleType

Abstract type used to define a `ScheduleConstraint` as a maximum constraint.
"""
abstract type MaxSchedule <: AbstractScheduleType end

"""
    abstract type EqualSchedule <: AbstractScheduleType

Abstract type used to define a `ScheduleConstraint` as a schedule constraint.
"""
abstract type EqualSchedule <: AbstractScheduleType end

"""
    ScheduleConstraint{T} <: Data where {T<:AbstractScheduleType}

A constraint that can be added as `Data`. `T <: AbstractScheduleType` denotes the constraint type.

## Fields
- **`resource::{Union{<:Resource, Nothing}}`** is the resource type the constraint applies
  to if the node can have multiple resources as input/outputs.
- **`value::TimeProfile`** is the constraint value, that is the limit that should not be violated.
- **`flag::TimeProfile`** is a boolean value indicating if the constraint is active.
- **`penalty::TimeProfile`** is the penalty for violating the constraint. If penalty is set
  to `Inf` it will be built as a hard constraint.
"""
struct ScheduleConstraint{T} <: Data where {T<:AbstractScheduleType}
    resource::Union{<:Resource, Nothing}
    value::TimeProfile{<:Number}
    flag::TimeProfile{Bool}
    penalty::TimeProfile{<:Number}
end

"""
    resource(data::ScheduleConstraint)

Returns the `Resource` type of a `ScheduleConstraint`.
"""
resource(data::ScheduleConstraint) = data.resource

"""
    is_constraint_data(data::Data)
    is_constraint_data(data::ScheduleConstraint)

Returns true if `Data` input is of type `ScheduleConstraint`, otherwise false.
"""
is_constraint_data(data::Data) = false
is_constraint_data(data::ScheduleConstraint) = true

"""
    constraint_data(n::EMB.Node)

Returns vector of `Data` that are of type `ScheduleConstraint`.
"""
constraint_data(n::EMB.Node) = filter(is_constraint_data, node_data(n))

"""
    is_constraint_resource(data::ScheduleConstraint, resource::Resource)

Returns true if `Data` is of type `ScheduleConstraint` and `ScheduleConstraint` resource type is `resource`.
"""
is_constraint_resource(data::ScheduleConstraint, resource::Resource) = resource == resource(data)

"""
    is_active(data::ScheduleConstraint, t)

Returns true if given constraint `data` is active at operational period `t`.
"""
is_active(data::ScheduleConstraint, t) = data.flag[t]

"""
    value(data::ScheduleConstraint, t)

Returns the value of a constraint `data` at operational period `t`.
"""
value(data::ScheduleConstraint, t) = data.value[t]

"""
    penalty(data::ScheduleConstraint, t)

Returns the penalty value of constraint `data` at operational period `t`.
"""
penalty(data::ScheduleConstraint, t) = data.penalty[t]

"""
    has_penalty(data::ScheduleConstraint, t)

Returns true if a constraint needs a penalty variable at operational period `t`.
"""
has_penalty(data::ScheduleConstraint, t) = !isinf(penalty(data, t)) & is_active(data, t)

"""
    has_penalty_up(data::ScheduleConstraint)
    has_penalty_up(data::ScheduleConstraint, t)
    has_penalty_up(data::ScheduleConstraint, t, p::Resource)

Returns true if a constraint `data` is of a type that may require a penalty up variable,
which is true for [`MinSchedule`](@ref) and [`EqualSchedule`](@ref).

When the operational period `t` is provided in addition, it is furthermore necessary that the
penalty is finite.

When the operational period `t` and the resource `p` is provided in addition, it is
furthermore necessary that the penalty is finite and that `p` corresponds to the `ScheduleConstraint`
resource.
"""
has_penalty_up(data::ScheduleConstraint) = false
has_penalty_up(data::ScheduleConstraint{MinSchedule}) = true
has_penalty_up(data::ScheduleConstraint{EqualSchedule}) = true
has_penalty_up(data::ScheduleConstraint, t) = has_penalty_up(data) & has_penalty(data, t)
has_penalty_up(data::ScheduleConstraint, t, p::Resource) =
    has_penalty_up(data, t) & (resource(data) == p)

"""
    has_penalty_down(data::ScheduleConstraint)
    has_penalty_down(data::ScheduleConstraint, t)
    has_penalty_down(data::ScheduleConstraint, t, resource::Resource)

Returns true if a constraint `data` is of a type that may require a penalty up down,
which is true for [`MaxSchedule`](@ref) and [`EqualSchedule`](@ref).

When the operational period `t` is provided in addition, it is furthermore necessary that the
penalty is finite.

When the operational period `t` and the resource `p` is provided in addition, it is
furthermore necessary that the penalty is finite and that `p` corresponds to the `ScheduleConstraint`
resource.
"""
has_penalty_down(data::ScheduleConstraint) = false
has_penalty_down(data::ScheduleConstraint{MaxSchedule}) = true
has_penalty_down(data::ScheduleConstraint{EqualSchedule}) = true
has_penalty_down(data::ScheduleConstraint, t) = has_penalty_down(data) & has_penalty(data, t)
has_penalty_down(data::ScheduleConstraint, t, p::Resource) =
    has_penalty_down(data, t) & (resource(data) == p)

"""
    HydroReservoir{T} <: EMB.Storage{T}

A regulated hydropower reservoir, modelled as a `Storage` node.

A `HydroReservoir` differs from [`HydroStor`](@ref) and[`PumpedHydroStor`](@ref) nodes as
it models the stored energy in the form of water through the potential energy.
It can only be used in conjunction with [`HydroGenerator`](@ref) nodes.

## Fields
- **`id`** is the name/identifyer of the node.
- **`vol::EMB.UnionCapacity`** are the storage volume parameters of the `HydroReservoir` node
  (typically million cubic meters).
- **`vol_inflow::TimeProfile`** is the water inflow to the reservoir
  (typically million cubic per time unit).
- **`stor_res::ResourceCarrier`** is the stored `Resource`.
- **`data::Vector{<:Data}`** is the additional data (*e.g.*, for investments or constraints
  through [`AbstractScheduleType`](@ref)). The field `data` is conditional through usage
  of a constructor.
"""
struct HydroReservoir{T} <: EMB.Storage{T}
    id::Any
    vol::EMB.UnionCapacity
    vol_inflow::TimeProfile
    stor_res::ResourceCarrier # Water
    data::Vector{<:Data}
end
function HydroReservoir{T}(
    id::Any,
    vol::EMB.UnionCapacity,
    vol_inflow::TimeProfile,
    stor_res::ResourceCarrier
    ) where {T<:EMB.StorageBehavior}
    return HydroReservoir{T}(
        id,
        vol,
        vol_inflow,
        stor_res,
        Data[],
    )
end

"""
    inputs(n::HydroReservoir)
    inputs(n::HydroReservoir, p::Resource)

Returns the input resources of a HydroReservoir `n`, specified *via* the field `stor_res`.

If the resource `p` is specified, it returns a value of 1. This behaviour should in theory
not occur.
"""
EMB.inputs(n::HydroReservoir) = [storage_resource(n)]
EMB.inputs(n::HydroReservoir, p::Resource) = 1

"""
    outputs(n::HydroReservoir)
    outputs(n::HydroReservoir, p::Resource)

Returns the output resources of a HydroReservoir `n`, specified *via* the field `stor_res`.

If the resource `p` is specified, it returns a value of 1. This behaviour should in theory
not occur.
"""
EMB.outputs(n::HydroReservoir) = [storage_resource(n)]
EMB.outputs(n::HydroReservoir, p::Resource) = 1

"""
    level(n::HydroReservoir)
    level(n::HydroReservoir, t)

Returns the `vol` parameter field of the HydroReservoir `n` either as `TimeProfile` or in
operational period `t`.
"""
EMB.level(n::HydroReservoir) = n.vol
EMB.level(n::HydroReservoir, t) = n.vol[t]

"""
    vol_inflow(n::HydroReservoir)
    vol_inflow(n::HydroReservoir, t)

Returns the inflow to a HydroReservoir `n` either as `TimeProfile` or in operational period
`t`.
"""
vol_inflow(n::HydroReservoir) = n.vol_inflow
vol_inflow(n::HydroReservoir, t) = n.vol_inflow[t]

"""
    HydroGate <: EMB.NetworkNode

A hydro gate, modelled as a `NetworkNode` node.

It an be used to model outlets/inlets and minimum/maximum requirements for water flow
between individual reservoirs without power generation.

## Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** is the installed discharge capacity.
- **`opex_var::TimeProfile`** is the variational operational costs per water flow through
  the gate.
- **`opex_fixed::TimeProfile`** is the fixed operational costs.
- **`resource::ResourceCarrier`** is the water resource type since gates are only used for
  discharging water.
- **`data::Vector{<:Data}`** is the additional data (*e.g.*, for investments or constraints
  through [`AbstractScheduleType`](@ref)). The field `data` is conditional through usage
  of a constructor.
"""
struct HydroGate <: EMB.NetworkNode
    id::Any
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    resource::ResourceCarrier
    data::Vector{<:Data}
end
function HydroGate(
    id::Any,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    resource::ResourceCarrier,
)
    return HydroGate(id, cap, opex_var, opex_fixed, resource, Data[])
end

"""
    inputs(n::HydroGate)
    inputs(n::HydroGate, p::Resource)

Returns the input resources of a HydroGate `n`, specified *via* the field `resource`.

If the resource `p` is specified, it returns a value of 1. This behaviour should in theory
not occur.
"""
EMB.inputs(n::HydroGate) = [n.resource]
EMB.inputs(n::HydroGate, p::Resource) = 1

"""
    outputs(n::HydroGate)
    outputs(n::HydroGate, p::Resource)

Returns the output resources of a HydroGate `n`, specified *via* the field `resource`.

If the resource `p` is specified, it returns a value of 1. This behaviour should in theory
not occur.
"""
EMB.outputs(n::HydroGate) = [n.resource]
EMB.outputs(n::HydroGate, p::Resource) = 1

"""
    abstract type HydroUnit <: EMB.NetworkNode

A Hydropower unit node for either pumping or production, modelled as a `NetworkNode` node.
"""
abstract type HydroUnit <: EMB.NetworkNode end

"""
    electricity_resource(n::HydroUnit)

Returns the resource of the `electricity_resource` field of a HydroUnit `n`.
"""
electricity_resource(n::HydroUnit) = n.electricity_resource

"""
    water_resource(n::HydroUnit)

Returns the resource of the `water_resource` field of a HydroUnit `n`.
"""
water_resource(n::HydroUnit) = n.water_resource

"""
    pq_curve(n::HydroUnit)

Returns the resources in the PQ-curve of a HydroUnit `n`.
"""
pq_curve(n::HydroUnit) = n.pq_curve

"""
    abstract type AbstractPqCurve

`AbstractPqCurve` type used to represent the relationship between discharge of water and
generation of electricity.
"""
abstract type AbstractPqCurve end

"""
    struct PqPoints <: AbstractPqCurve
    PqPoints(power_levels::Vector{Real}, discharge_levels::Vector{Real})
    PqPoints(eq::Real)

The relationship between discharge/pumping of water and power generation/consumption
represented by a set of discharge and power values (PQ-points).

## Fields
- **`power_levels::Vector{Real}`** is a vector of power values.
- **`discharge_levels::Vector{Real}`** is a vector of discharge values.

The two vectors muct be of equal size and ordered so that the power and discharge values
describes the conversion from energy (stored in the water) to electricity (power) for a
[`HydroGenerator`](@ref) node or the conversion from electric energy to energy stored as
water in the reservoirs for a [`HydroPump`](@ref) node.

The first value in each vector should be zero. Furthermore, the vectors should be relative
to the installed capacity, so that either the power-vector or the discharge vector is in the
range [0, 1].

If a single `Real` is provided as input, it constructs the two Arrays through the energy
equivalent input. If this approach is used, the installed capacity of the node must refer
to the power capacity of a [`HydroGenerator`](@ref) or [`HydroPump`](@ref) node.

!!! note
    The described power-discharge relationship should be concave for a [`HydroGenerator`](@ref)
    node and convex for a [`HydroPump`](@ref) node.
"""
struct PqPoints <: AbstractPqCurve
    power_levels::Vector{Real}
    discharge_levels::Vector{Real}
end
function PqPoints(eq::Real)
    return PqPoints(
        [0.0, 1],
        [0.0, 1.0 / eq]
    )
end

"""
    power_level(pq::PqPoints)
    power_level(pq::PqPoints, i)

Returns the power level of PqPoint `pq` as array or at index `i`.
"""
power_level(pq::PqPoints) = pq.power_levels
power_level(pq::PqPoints, i) = pq.power_levels[i]

"""
    discharge_level(pq::PqPoints)
    discharge_level(pq::PqPoints, i)

Returns the discharge level of PqPoint `pq` as array or at index `i`.
"""
discharge_level(pq::PqPoints) = pq.discharge_levels
discharge_level(pq::PqPoints, i) = pq.discharge_levels[i]

"""
    HydroGenerator <: HydroUnit

A hydropower generator, modelled as a `HydroUnit` node.

A hydropower generator is located between two [`HydroReservoir`](@ref)s or between a
[`HydroReservoir`](@ref) and a `Sink` node corresponding to the ocean. It differs from a
[`HydroGate`](@ref) as it allows for power generation desctibed through an
[`AbstractPqCurve`](@ref).

## Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** is the installed discharge or power capacity.
- **`pq_curve::AbstractPqCurve` describes the relationship between power and discharge (water).
- **`opex_var::TimeProfile`** is the variable operational costs per energy unit produced.
- **`opex_fixed::TimeProfile`** is the fixed operational costs.
- **`electricity_resource::Resource`** is the electricity resource generated as output.
- **`water_resource::Resource`** is the water resource taken as input and discharged as output.
- **`data::Vector{<:Data}`** is the additional data (*e.g.*, for investments or constraints
  through [`AbstractScheduleType`](@ref)). The field `data` is conditional through usage
  of a constructor.
"""
struct HydroGenerator <: HydroUnit
    id::Any
    cap::TimeProfile
    pq_curve::AbstractPqCurve
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    electricity_resource::Resource
    water_resource::Resource
    data::Vector{<:Data}
end
function HydroGenerator(
    id::Any,
    cap::TimeProfile,
    pq_curve::AbstractPqCurve,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    electricity_resource::Resource,
    water_resource::Resource,
)
    return HydroGenerator(id, cap, pq_curve, opex_var, opex_fixed,
        electricity_resource, water_resource, Data[])
end

"""
    inputs(n::HydroGenerator)
    inputs(n::HydroGenerator, p::Resource)

Returns the input resources of a HydroGenerator `n`, specified *via* the field
`water_resource`.

If the resource `p` is specified, it returns a value of 1. This behaviour should in theory
not occur.
"""
EMB.inputs(n::HydroGenerator) = [water_resource(n)]
EMB.inputs(n::HydroGenerator, p::Resource) = 1

"""
    outputs(n::HydroGenerator)
    outputs(n::HydroGenerator, p::Resource)

Returns the output resources of a HydroGenerator `n`, specified *via* the fields
`water_resource` and `electricity_resource`.

If the resource `p` is specified, it returns a value of 1. This behaviour should in theory
not occur.
"""
EMB.outputs(n::HydroGenerator) = [water_resource(n), electricity_resource(n)]
EMB.outputs(n::HydroGenerator, p::Resource) = 1

"""
    HydroPump <: HydroUnit

A hydropower pump, modelled as a `HydroUnit` node.

A hydropower pump is located between two [`HydroReservoir`](@ref)s and allows the transfer
of water from one reservoir to the other through pumping the water.

## Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** is the installed pumping capacity in piwer or volume per time unit.
- **`pq_curve::AbstractPqCurve` describes the relationship between power and pumping of water.
- **`opex_var::TimeProfile`** is the variable operational costs per energy unit produced.
- **`opex_fixed::TimeProfile`** is the fixed operational costs.
- **`electricity_resource::Resource`** is the electricity resource taken as input (consumed).
- **`water_resource::Resource`** is the water resource taken as input and discharged (pumped) as output.
- **`data::Vector{<:Data}`** is the additional data (*e.g.*, for investments or constraints
  through [`AbstractScheduleType`](@ref)). The field `data` is conditional through usage
  of a constructor.
"""
struct HydroPump <: HydroUnit
    id::Any
    cap::TimeProfile
    pq_curve::AbstractPqCurve
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    electricity_resource::Resource
    water_resource::Resource
    data::Vector{<:Data}
end
function HydroPump(
    id::Any,
    cap::TimeProfile,
    pq_curve::AbstractPqCurve,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    electricity_resource::Resource,
    water_resource::Resource,
)
    return HydroPump(id, cap, pq_curve, opex_var, opex_fixed,
        electricity_resource, water_resource, Data[])
end

"""
    inputs(n::HydroPump)
    inputs(n::HydroPump, p::Resource)

Returns the input resources of a HydroPump `n`, specified *via* the fields `water_resource`
and `electricity_resource`.

If the resource `p` is specified, it returns a value of 1. This behaviour should in theory
not occur.
"""
EMB.inputs(n::HydroPump) = [water_resource(n), electricity_resource(n)]
EMB.inputs(n::HydroPump, p::Resource) = 1

"""
    outputs(n::HydroPump)
    outputs(n::HydroPump, p::Resource)

Returns the output resources of a HydroPump `n`, specified *via* the field `water_resource`.

If the resource `p` is specified, it returns a value of 1. This behaviour should in theory
not occur.
"""
EMB.outputs(n::HydroPump) = [water_resource(n)]
EMB.outputs(n::HydroPump, p::Resource) = 1


"""
    discharge_segments(pq_curve::PqPoints)

Returns the range of segment indices for a PqPoints `pq_curve`.
"""
discharge_segments(pq_curve::PqPoints) = range(1, length(pq_curve.discharge_levels) - 1)

"""
    max_power(n::HydroUnit)

Returns the maximum power of HydroUnit `n` based on the pq_curve input.
"""
function max_power(n::HydroUnit)
    if pq_curve(n) isa PqPoints
        return pq_curve(n).power_levels[end]
    end
end

"""
    max_flow(n::HydroUnit)

Returns the maximum flow of HydroUnit `n` based on the pq_curve input.
"""
function max_flow(n::HydroUnit)
    if pq_curve(n) isa PqPoints
        return pq_curve(n).discharge_levels[end]
    end
end

"""
    capacity(n::HydroUnit, t, p::Resource)
    capacity(n::HydroGate, t, p::Resource)

Returns the capacity of HydroUnit `n` in operational period `t` for a given resource `p`.
In the case of a `HydroGate`, this function reverts to `capacity(n, t)` to allow its
application in multiple methods.

!!! warning
    The resource `p` **must** be either the `electricity_resource` or `water_resource`.
    Otherwise, an error is raised.
"""
function EMB.capacity(n::HydroUnit, t, p::Resource)
    if p == electricity_resource(n)
        return capacity(n, t) * max_power(n)
    elseif p == water_resource(n)
        return capacity(n, t) * max_flow(n)
    end
    throw(
        "The Resource `p` the function capacity(n, t, p) must be either the water or " *
        "electricity resource of HydroUnit `n`.")
end
EMB.capacity(n::HydroGate, t, p::Resource) = EMB.capacity(n, t)
