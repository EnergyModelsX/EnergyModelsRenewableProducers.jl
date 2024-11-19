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
    abstract type AbstractConstraintType

Abstract supertype for the different constraint types.
"""
abstract type AbstractConstraintType end

"""
    abstract type MinConstraintType <: AbstractConstraintType

Abstract type used to define a `Constraint` as a minimum constraint.
"""
abstract type MinConstraintType <: AbstractConstraintType end

"""
    abstract type MaxConstraintType <: AbstractConstraintType

Abstract type used to define a `Constraint` as a maximum constraint.
"""
abstract type MaxConstraintType <: AbstractConstraintType end

"""
    abstract type ScheduleConstraintType <: AbstractConstraintType

Abstract type used to define a `Constraint` as a schedule constraint.
"""
abstract type ScheduleConstraintType <: AbstractConstraintType end

"""
    Constraint{T} <: Data where {T<:AbstractConstraintType}

A constraint that can be added as `Data`. `T <: AbstractConstraintType` denotes the constraint type.

## Fields
- **`resource::{Union{<:Resource, Nothing}}`** is the resource type the constraint applies
  to if the node can have multiple resources as input/outputs.
- **`value::TimeProfile`** is the constraint value, the limit that should not be violated.
- **`flag::TimeProfile`** is a boolean value indicating if the constraint is active.
- **`penalty::TimeProfile`** is the penalty for violating the constraint. If penalty is set
  to `Inf` it will be built as a hard constraint.
"""
struct Constraint{T} <: Data where {T<:AbstractConstraintType}
    resource::Union{<:Resource, Nothing} # Should be specified for nodes with multiple input/output resources
    value::TimeProfile{<:Number}
    flag::TimeProfile{Bool}
    penalty::TimeProfile{<:Number}
end

"""
    resource(data::Constraint)

Returns the `Resource` type of a `Constraint`.
"""
resource(data::Constraint) = data.resource

"""
    is_constraint_data(data::Data)
    is_constraint_data(data::Constraint)

Returns true if `Data` input is of type `Constraint`, otherwise false.
"""
is_constraint_data(data::Data) = false
is_constraint_data(data::Constraint) = true

"""
    constraint_data(n::EMB.Node)

Returns vector of `Data` that are of type `Constraint`.
"""
constraint_data(n::EMB.Node) = filter(is_constraint_data, node_data(n))

"""
    is_constraint_resource(data::Constraint, resource::Resource)

Returns true if `Data` is of type `Constraint` and `Constraint` resource type is `resource`.
"""
is_constraint_resource(data::Constraint, resource::Resource) = resource == data.resource

"""
    is_active(data::Constraint, t)

Returns true if given constraint is active at time step `t`.
"""
is_active(data::Constraint, t) = data.flag[t]

"""
    value(data::Constraint, t)

Returns the value of a constraint at time step `t`.
"""
value(data::Constraint, t) = data.value[t]

"""
    penalty(data::Constraint, t)

Returns penalty value of constraint.
"""
penalty(data::Constraint, t) = data.penalty[t]

"""
    has_penalty(data::Constraint, t)

Returns true if a constraint needs a penalty variable at time step `t`.
"""
has_penalty(data::Constraint, t) = !isinf(penalty(data, t)) & is_active(data, t)

"""
    has_penalty_up(data::Constraint)

Returns true if a constraint is of a type that may require a penalty up variable, which is
true for `MinConstraintType` and `ScheduleConstraintType`.
"""
has_penalty_up(data::Constraint) = false
has_penalty_up(data::Constraint{MinConstraintType}) = true
has_penalty_up(data::Constraint{ScheduleConstraintType}) = true

"""
    has_penalty_up(data::Constraint, t)
    has_penalty_up(data::Constraint, t, resource::Resource)

Returns true if a constraint requires a penalty up variable at time step `t`. The constraint
must be of the right type, have a non-infinite penalty and be active a the current time step
`t`. For nodes where schedule can apply for different resource types, the `resource` must
also match the constraint resource.
"""
has_penalty_up(data::Constraint, t) = has_penalty_up(data) & has_penalty(data, t)
has_penalty_up(data::Constraint, t, resource::Resource) = has_penalty_up(data, t) & (data.resource == resource)

"""
    has_penalty_down(data::Constraint)

Returns true if a constraint is of a type that may require a penalty down variable, which is
true for `MaxConstraintType` and `ScheduleConstraintType`.
"""
has_penalty_down(data::Constraint) = false
has_penalty_down(data::Constraint{MaxConstraintType}) = true
has_penalty_down(data::Constraint{ScheduleConstraintType}) = true

"""
    has_penalty_down(data::Constraint, t)
    has_penalty_down(data::Constraint, t, resource::Resource)

Returns true if a constraint requires a penalty down variable at time step `t`. The constraint
must be of the right type, have a non-infinite penalty and be active a the current time step
`t`. For nodes where schedule can apply for different resource types, the `resource` must
also match the constraint resource.
"""
has_penalty_down(data::Constraint, t) = has_penalty_down(data) & has_penalty(data, t)
has_penalty_down(data::Constraint, t, resource::Resource) = has_penalty_down(data, t) & (data.resource == resource)

"""
    HydroReservoir{T} <: EMB.Storage{T}

A regulated hydropower reservoir, modelled as a `Storage` node. A regulated hydro storage node
requires a storage volume for the `vol` and volume inflow `vol_inflow`. The `stor_res`
represents water. Minimum, maximum and schedule volume constraints can be added using `Data`
input of the composite type `Constraint`.
These are given relative sizes between 0 and 1 relative to the total storage volume `vol`.

## Fields
- **`id`** is the name/identifyer of the node.\n
- **`vol::EMB.UnionCapacity`** are the storage volume parameters of the HydroReservoir node
  (typically million cubic meters).
- **`vol_inflow::TimeProfile`** is the inflow to the reservoir (typically million cubic per time unit).
- **`stor_res::ResourceCarrier`** is the stored `Resource`.\n
- **`data::Vector{Data}`** additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.
"""
struct HydroReservoir{T} <: EMB.Storage{T}
    id::Any
    vol::EMB.UnionCapacity
    vol_inflow::TimeProfile
    stor_res::ResourceCarrier # Water
    input::Dict{<:Resource,<:Real} # Water
    output::Dict{<:Resource,<:Real} # Water
    data::Vector{<:Data}
end
function HydroReservoir{T}(
    id::Any,
    vol::EMB.UnionCapacity,
    vol_inflow::TimeProfile,
    stor_res::ResourceCarrier,
    data::Vector{<:Data}
) where {T<:EMB.StorageBehavior}
    HydroReservoir{T}(
        id,
        vol,
        vol_inflow,
        stor_res,
        Dict(stor_res => 1.0),
        Dict(stor_res => 1.0),
        data
    )
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
    level(n::HydroReservoir)
    level(n::HydroReservoir, t)

Returns the `vol` parameter field of the node either as `TimeProfile`. or in operational
period `t`.
"""
EMB.level(n::HydroReservoir) = n.vol
EMB.level(n::HydroReservoir, t) = n.vol[t]

"""
    vol_inflow(n::HydroReservoir)
    vol_inflow(n::HydroReservoir, t)

Returns the inflow to a node `n` of type `HydroReservoir` either as `TimeProfile` or in
operational period `t`.
"""
vol_inflow(n::HydroReservoir) = n.vol_inflow
vol_inflow(n::HydroReservoir, t) = n.vol_inflow[t]

"""
    HydroGate <: EMB.NetworkNode

A Hydro Gate, modelled as a `NetworkNode` node. Can be used to model outlets/inlets and
minimum/maximum requirements for water flow.

## Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** is the installed discharge capacity.
- **`opex_var::TimeProfile`** is the variational operational costs per energy unit produced.
- **`opex_fixed::TimeProfile`** is the fixed operational costs.
- **`resource<:Resource`** is the water resource type since gates are only used for dispatching water.
- **`data::Vector{Data}`** is the additional data (e.g. for investments). The field
  `data` is conditional through usage of a constructor.
"""
struct HydroGate <: EMB.NetworkNode
    id::Any
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    input::Dict{<:Resource,<:Real}
    output::Dict{<:Resource,<:Real}
    data::Vector{<:Data}
end
function HydroGate(
    id::Any,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    resource::ResourceCarrier,
    data::Vector{<:Data}
)
    HydroGate(
        id,
        cap,
        opex_var,
        opex_fixed,
        Dict(resource => 1.0),
        Dict(resource => 1.0),
        data
    )
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
    HydroUnit <: EMB.NetworkNode

A Hydropower unit node for either pumping or production, modelled as a `NetworkNode` node.
"""
abstract type HydroUnit <: EMB.NetworkNode end

"""
    AbstractPqCurve

`AbstractPqCurve` type used to represent the relatioship between discharge of water and generation of electricity.
"""
abstract type AbstractPqCurve end

"""
    PqPoints <: AbstractPqCurve

The relationship between discharge/pumping of water and power generation/consumption represented \
by a set of discharge and power values (PQ-points).

## Fields
- **`power_levels::Vector{Real}`** is a vector of power values.
- **`discharge_levels::Vector{Real}`** is a vector of discharge values.

The two vectors muct be of equal size and ordered so that the power and discharge values
describes the convertion from energy (stored in the water) to electricity (power) for a
`HydroGenerator` node or the convertion from electric energy to energy stored as water in
the reservoirs for a `HydroPump` node.
The first value in each vector should be zero. Furthermore, the vectors should relative to
the installed capacity, so that either the power-vector or the discharge vector is in the
range [0, 1].
The described power-discharge relationship should be concave for a `HydroGenerator` node and
convex for a `HydroPump` node.
"""
struct PqPoints <: AbstractPqCurve
    power_levels::Vector{Real}  # MW / m3/s
    discharge_levels::Vector{Real} #share of total discharege capacity (0,1)
end

"""
    PqPoints(eq::Real)

Construct a PqPoints description based on energy equivalent input. If this function is used,
the installed capacity of the node must refer to the power capacity of the `HydroGenerator`
or `HydroPump` node.
"""
function PqPoints(eq::Real)
    return PqPoints(
        [0.0, 1],
        [0.0, 1.0 / eq]
    )
end

"""
    power_level(pq::PqPoints, i)

Returns the power level at `PqPoint` with index `i`.
"""
power_level(pq::PqPoints, i) = pq.power_levels[i]

"""
    discharge_level(pq::PqPoints, i)

Returns the discharge level at `PqPoint` with index `i`.
"""
discharge_level(pq::PqPoints, i) = pq.discharge_levels[i]

"""
    HydroGenerator <: HydroUnit

A regular hydropower plant, modelled as a `HydroUnit` node.

## Fields
- **`id`** is the name/identifier of the node.\n
- **`cap::TimeProfile`** is the installed discharge or power capacity.\n
- **`pq_curve::AbstractPqCurve` describes the relationship between power and discharge (water).\
- **`opex_var::TimeProfile`** is the variable operational costs per energy unit produced.\n
- **`opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`electricity_resource::Resource`** is the electricity resource generated as output.\n
- **`water_resource::Resource`** is the water resource taken as input and discharged as output.\n
- **`data::Vector{Data}`** is the additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.
"""
struct HydroGenerator <: HydroUnit
    id::Any
    cap::TimeProfile
    pq_curve::AbstractPqCurve
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    electricity_resource::Resource
    water_resource::Resource
    input::Dict{<:Resource,<:Real}
    output::Dict{<:Resource,<:Real}
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

    input = Dict(water_resource => 1.0)
    output = Dict(water_resource => 1.0, electricity_resource => 1.0)

    return HydroGenerator(id, cap, pq_curve, opex_var, opex_fixed,
        electricity_resource, water_resource, input, output, Data[])
end

"""
    HydroPump <: HydroUnit

A regular hydropower pump, modelled as a `HydroUnit` node.

## Fields
- **`id`** is the name/identifier of the node.\n
- **`cap::TimeProfile`** is the installed pumping capacity in piwer or volume per time unit.\n
- **`pq_curve::AbstractPqCurve` describes the relationship between power and pumping of water.\
- **`opex_var::TimeProfile`** is the variable operational costs per energy unit produced.\n
- **`opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`electricity_resource::Resource`** is the electricity resource taken as input (consumed).\n
- **`water_resource::Resource`** is the water resource taken as input and discharged (pumped) as output.\n
- **`data::Vector{Data}`** is the additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.
"""
struct HydroPump <: HydroUnit
    id::Any
    cap::TimeProfile
    pq_curve::AbstractPqCurve
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    electricity_resource::Resource
    water_resource::Resource
    input::Dict{<:Resource,<:Real}
    output::Dict{<:Resource,<:Real}
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

    input = Dict(water_resource => 1.0, electricity_resource => 1.0)
    output = Dict(water_resource => 1.0)

    return HydroPump(id, cap, pq_curve, opex_var, opex_fixed,
        electricity_resource, water_resource, input, output, Data[])
end

"""
    electricity_resource(n::HydroUnit)

Returns the resource of the `electricity_resource` field of a node `n`.
"""
electricity_resource(n::HydroUnit) = n.electricity_resource

"""
    water_resource(n::HydroUnit)

Returns the resource of the `water_resource` field of a node `n`.
"""
water_resource(n::HydroUnit) = n.water_resource

"""
    pq_curve(n::HydroUnit)

Returns the resources in the PQ-curve of a node `n` of type `HydroUnit`
"""
pq_curve(n::HydroUnit) = n.pq_curve

"""
    discharge_segments(pq_curve::PqPoints)

Returns the range of segment indices for given `PqPoints`.
"""
discharge_segments(pq_curve::PqPoints) = range(1, length(pq_curve.discharge_levels) - 1)

"""
    max_power(n::HydroUnit)

Returns the maximum power of `HydroUnit` based on pq_curve input.
"""
function max_power(n::HydroUnit)
    if pq_curve(n) isa PqPoints
        return pq_curve(n).power_levels[end]
    end
end

"""
    max_flow(n::HydroUnit)

Returns the maximum flow of `HydroUnit` based on pq_curve input.
"""
function max_flow(n::HydroUnit)
    if pq_curve(n) isa PqPoints
        return pq_curve(n).discharge_levels[end]
    end
end

"""
    capacity(n::HydroUnit, t, p::Resource)

Returns the `HydroUnit` capacity for a given resource `p` (either power or flow).
"""
function EMB.capacity(n::HydroUnit, t, p::Resource)
    if p == electricity_resource(n)
        return capacity(n, t) * max_power(n)
    elseif p == water_resource(n)
        return capacity(n, t) * max_flow(n)
    end
    throw("Hydro HydroUnit capacity resource has to be either water or electricity.")
end

"""
    capacity(n::HydroGate, t, p::Resource)

Returns the `HydroGate` capacity. The resource `p` is ignored since `HydroGate` only can
have one resource type.
Function has been implemented to allow using the same function for building constraints
for both `HydroGate` and `HydroUnit`.
"""
EMB.capacity(n::HydroGate, t, p::Resource) = EMB.capacity(n, t)
