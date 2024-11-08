# [Hydro generator node](@id nodes-hydro_generator)

The [`HydroReservoir`](@ref), [`HydroGate`](@ref), [`HydroGenerator`](@ref), and [`HydroPump`](@ref) should be used for detailed hydropower modeling.
Unlike [`HydroStorage`](@ref), [`HydroReservoir`](@ref) can have water as the stored resource.
[`HydroGenerator`](@ref) can produce electricity by moving water to a lower reservoir or the ocean that should be represented as a [`RefSink`](@extref EnergyModelsBase.RefSink).
Likewise, [`HydroPump`](@ref) can consume electricity by moving water to a higher reservoir.
[`HydroGate`](@ref) can discharge to lower reservoirs without producing electricity, for example due to spillage or environmental restrictions in the water course.

## [Introduced type and its field](@id nodes-hydro_generator-fields)
The [`HydroGenerator`](@ref) node represents a hydropower unit used to generate electricity in a hydropower system. In its simplest form, the [`HydroGenerator`](@ref) can convert potential energy stored in the reservoirs to electricity by discharging water between reservoirs at different head levels under the assumption that the reservoirs has constant head level. The conversion to electric energy can be described by an power-discharge realtionship referred to as the PQ-curve.

### [Fields](@id nodes-hydro_generator-fields-stand)
[`HydroGenerator`](@ref) nodes builds on the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) and the  [`RefNetworkNode` ](@extref EnergyModelsBase.RefNetworkNode) nodes, but add additional fields. The following gives the fields of the [`HydroGenerator`](@ref) node and describes the differences from standard fields. See [`RefNetworkNode`](@extref EnergyModelsBase.RefNetworkNode) for information about the standard fields.

- **`id`**\
- **`cap::TimeProfile`**: Can refer to either the installed power or discharge capactiy of the hydropower unit. 
- **`pq_curve::AbstractPqCurve`**: Describes the relationship between generater power (electricity) and discharge of water. 

- **`opex_var::TimeProfile`**\
- **`opex_fixed::TimeProfile`**\
- **`water_resource::Resource`**: The water resource that the node discharge to generate electricity.
- **`electricity_resource::Resource`**: The electricity resource generated from the node.
- **`data::Vector{Data}`**: An entry for providing additional data to the model. 


**`pq_curve::AbstractPqCurve`**. There is currently two options to provide input to the `pq_curve` field: either by using the subtype [`PqPoints`](@ref), a struct that takes vectors of related power and discharge values as input, or by using the [EnergyEquivalent](@ref EnergyModelsRenewableProducers.EnergyEquivalent) function that takes a single energy equivalent as input. The  [`PqPoints`](@ref) are defined so that either the maximum discharge or the maximum power value given by the [`PqPoints`](@ref) equals 1. This approach makes if possible to freely chose the capacity of the node (provided in the **`cap::TimeProfile`** field) to represent the power capacity or the discharge capacity of the node when setting up det hydropower system. NB: If an energy equivalent is used the **`cap::TimeProfile`** must refer to the discharge capacity of the [`HydroGenerator`](@ref) node.

**`data::Vector{Data}`** could be used to add minimum, maximum and schedule constraints for the discharge using [Constraint{T<:AbstractConstraintType}](@ref EnergyModelsRenewableProducers.Constraint), where [AbstractConstraintType](@ref EnergyModelsRenewableProducers.AbstractConstraintType) has subtypes [MinConstraintType](@ref EnergyModelsRenewableProducers.MinConstraintType), [MaxConstraintType](@ref EnergyModelsRenewableProducers.MaxConstraintType), and [ScheduleConstraintType](@ref EnergyModelsRenewableProducers.ScheduleConstraintType). Such constraints can be used to, for example, enforce minimum discharge due to environmental considerations. The constraints values are relative to the gate capacity.

The **`output::Dict{<:Resource, <:Real}`** and **`input::Dict{<:Resource, <:Real}`** fields of the [`RefNetworkNode`](@extref EnergyModelsBase.RefNetworkNode) nodes are set internally and not used to decribe the conversion between energy sources in the [`HydroGenerator`](@ref) nodes. Instead the **`pq_curve::AbstractPqCurve`** is used to describe the conversion in combination with the  **`water_resource::Resource`** and  **`electricity_resource::Resource`** fields.


## [Mathematical description](@id nodes-hydro_generator-math)

The [`HydroGenerator`](@ref) inherits its mathematical description from the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) and [NetworkNode](@extref EnergyModelsBase.NetworkNode).  There is a single input resource given by the `water_resource` field, and two output resources given by the `water_resource` and `electricity_resource` fields. The conversion value for the `water_resource` is set to 1, while the conversion to the `electricity_resource` is constrained by the input provided in the `pq_curve` field.

### [Variables](@id nodes-hydro_generator-math-var)

#### [Standard variables](@id nodes-hydro_generator-math-var-stand)

The [`HydroGenerator`](@ref) utilizes the standard variables from the `NetworkNode`, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*. 

#### [Additional variables](@id nodes-hydro_generator-math-add)

In addition to the standard variables, the variables presented below are defined for [`HydroUnit`](@ref) nodes. These variabels are created for both [`HydroGenerator`](@ref) and [`HydroPump`](@ref) nodes.
- ``\texttt{discharge\_segments}[n, t, q]``: One discharge variable is defined for each segment `q` of the PQ-curve defined by the  `pq_curve` field in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit. 

If [`PqPoints`](@ref) are provided, the number of discharge segments will be Q, where Q+1 is the length of the vectors in the fields of [`PqPoints`](@ref). There is only one discharge segment if an [EnergyEquivalent](@ref EnergyModelsRenewableProducers.EnergyEquivalent) is used. The ``\texttt{discharge\_segments}`` variables define the utilisation of each discharge segment and sums up to the total discharge. Sequential allocation is not enforced by binary variables, but will occure sequentially if the problem if set up correctly. NB: penalties for spilling water, a non-concave PQ-curve or an otherwise non-convex problem are examples thay may result in a non-sequential allocation.   

The following variables are created if penalties of violating maximum discharge or power generation constraints are provided:
- ``\texttt{gen\_penalty\_up}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction up in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.
- ``\texttt{gen\_penalty\_down}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction down in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.

### [Constraints](@id nodes-hydro_generator-math-con)
In the following sections the vector of `HydroGenerator` nodes are omitted from the descriptions.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroGenerator`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods). 

#### [Standard constraints](@id nodes-hydro_generator-math-con-stand)

The `HydroGenerator` nodes utilize the majority of the concepts from `EnergyModelsBase`. Some adjustments are required in the constraints to restrict the variables ``\texttt{cap\_use}``, ``\texttt{flow\_in}`` and ``\texttt{flow\_out}``. This is achieved through dispatching on the following standard constraints for `HydroUnit` nodes (used for both `HydroGenerator` and `HydroPump` nodes):

- the capacity constraint `constraints_capacity`,

```math
\begin{aligned}
    \texttt{cap\_use}&[n, t] \leq \texttt{cap\_inst}[n, t] \times \frac{P^{MAX}}{capacity(n, t)}\\
\end{aligned}
```
Where `capacity(n, t)` is the installed capacity of node `n` in operational period `t` and ``P^{MAX}`` is the maximum power capacity.

Furthermore, we dispatche on the flow constraints for `HydroGenerator` nodes:

- flow into the node `constraints_flow_in`,

```math
\begin{aligned}
    \texttt{flow\_in}&[n, t, water\_resource] = \texttt{flow\_out}[n, t, water\_resource] \\ 
\end{aligned}
```

-  flow out of the node `constraints_flow_out`,

```math
\begin{aligned}
    \texttt{flow\_out}&[n, t, water\_resource] = \sum_{q=1}^{Q}\texttt{discharge\_segments[n,t,q]} \\  
    \texttt{flow\_out}&[n, t, electricity\_resource] = \texttt{cap\_use}[n, t] \\ 
    \texttt{cap\_use}&[n, t] = \sum_{q=1}^{Q}(\texttt{discharge\_segments}[n,t,q] \times \texttt{E[q]})\  
\end{aligned}
```

```math
\begin{aligned}
    \texttt{discharge\_segment}&[n, t, q] \leq capacity(n, t) \times (discharge\_levels[q+1] - discharge\_levels[q]) \qquad  \forall q \in [1,Q] \\  
\end{aligned}
```

It is assumed that the amount of water is constant for `HydroGenerator` nodes, and the flow of water into the node therefore equals the flow out. The flow out of water is constrained to total discharge given by the sum of the ``\texttt{discharge\_segments[n,t,q]}`` variables, where Q is the number of segments in the PQ-curve (i.e., Q+1 PQ-points). The flow of electricity out of the node is given by the ``\texttt{cap\_use}[n, t]`` variables. In addition to being constrained by the installed capacity, the ``\texttt{cap\_use}`` variables are constrained by the discharge of water multiplied with the conversion rate given by ``\texttt{E[q]}`` which is the slope of each segment in the PQ-curve. 

The discharge segments are constrained by the ``\texttt{discharge\_levels}`` provided in the **`discharge_levels::Vector{Real}`** field of the [`PqPoints`](@ref). The `capacity(n, t)` refer to the installed capacity and is included to scale the input back to the absolute values. If an [EnergyEquivalent](@ref EnergyModelsRenewableProducers.EnergyEquivalent) is used, two points (zero and max) are created to describe a single discharge segment with the slope of the energy equivalent and the capacity of node `n`.

 The  [`PqPoints`](@ref) are defined so that either the maximum discharge or the maximum power value given by the [`PqPoints`](@ref) equals 1. This approach makes if possible to freely chose the capacity of the node (provided in the **`cap::TimeProfile`** field) to represent the power capacity or the discharge capacity of the node when setting up det hydropower system. NB: If an energy equivalent is provided as input to the **`pq_curve::AbstractPqCurve`** field, the capacity of the node has to refer to the discharge capacity. 


-`constraints_opex_var`

```math
\begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\
    \sum_{t \in t_{inv}} \Big( &opex\_var(n, t) \times \texttt{cap\_use}[n, t] + \\&
    penalty(c_{up}, t) \times \texttt{gen\_penalty\_up}[n, t] + \\&
    penalty(c_{down}, t) \times \texttt{gen\_penalty\_down}[n, t] \Big) \times scale\_op\_sp(t_{inv}, t)
\end{aligned}
```

We dispatch on the `constraints_opex_var` constraints for `HydroUnit` nodes to include penalty variables for violating maximum and minimum discharge constraints when required.


#### [Additional constraints](@id nodes-hydro_generator-math-con-add)

1. the discharge constraints if additional constraints exist on the `Data` field,

```math
\begin{aligned}
    \texttt{flow\_out}&[n, t, p] \geq capacity(n, t) \times value(c, t) \\
    \texttt{flow\_out}&[n, t, p] \leq capacity(n, t) \times value(c, t) \\
    \texttt{flow\_out}&[n, t, p] = capacity(n, t) \times value(c, t)
\end{aligned}
```

2. the discharge constraints including penalty if the constraints has non-infinite penalty value.

```math
\begin{aligned}
    \texttt{flow\_out}&[n, t, p] + \texttt{gen\_penalty\_up}[n, t] \geq \\ &
        capacity(n, t) \times value(c, t) \\
    \texttt{flow\_out}&[n, t, p] - \texttt{gen\_penalty\_down}[n, t] \leq \\ &
        capacity(n, t) \times value(c, t) \\
    \texttt{flow\_out}&[n, t, p] + \texttt{gen\_penalty\_up}[n, t] - \texttt{gen\_penalty\_down}[n, t] = \\&
        capacity(n, t) \times value(c, t)
\end{aligned}
```

The ``\texttt{gen\_penalty\_up}[n, t]`` and ``\texttt{gen\_penalty\_down}[n, t]`` variables are only added if required in a constraint, where ``c_{up}`` denotes constraint requiring up penalty, and ``c_{down}`` denotes constraint requiring down penalty.

##### [Constraints calculated in `create_node`](@id nodes-hydro_generator-math-con-add-node)

##### [Level constraints](@id nodes-hydro_generator-math-con-add-level)
