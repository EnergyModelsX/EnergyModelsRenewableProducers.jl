# [Hydro gate node](@id nodes-hydro_gate)

The [`HydroGate`](@ref) is one the nodes used for modelling detailed hydropower in combination with the nodes [`HydroReservoir`](@ref), , [`HydroGenerator`](@ref), and [`HydroPump`](@ref).

## [Introduced type and its field](@id nodes-hydro_gate-fields)
The [`HydroGate`](@ref) is used when water can be released between reservoirs without going through a generator. The [`HydroGate`](@ref) can either represent a controlled gate that is used to regulate the dispatch from a reservoir without proudction, or to bypass water when a reservoir is, for example, full. The [`HydroGate`](@ref) can also be used to represent spillage. Althoug spillage is not, in reality, a control decisions but a consequence of full reservoir, it is often modelled as a controllable decisions since state dependent spillage can not be modelled directly in a linear model. Costs for operating gates can be added to penalize unwanted spillage using the opex_var field.

### [Standard fields](@id nodes-hydro_gate-fields-stand)
The standard fields are given as:

- **`id`**:\
  The field **`id`** is only used for providing a name to the node.
- **`cap::TimeProfile`**:\
  The installed gate discharge capacity.
- **`opex_var::TimeProfile`**:\
  The variable operational expenses are based on the capacity utilization through the variable [`:cap_use`](@extref EnergyModelsBase man-opt_var-cap).
- **`opex_fixed::TimeProfile`**:\
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of a strategic period as outlined on *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS)*.\
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`resource::Resource`**:\
  The water resource that the node can release.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model. Could be used to add minimum, maximum and schedule constraints for the discharge using [Constraint{T<:AbstractConstraintType}](@ref EnergyModelsRenewableProducers.Constraint), where [AbstractConstraintType](@ref EnergyModelsRenewableProducers.AbstractConstraintType) has subtypes [MinConstraintType](@ref EnergyModelsRenewableProducers.MinConstraintType), [MaxConstraintType](@ref EnergyModelsRenewableProducers.MaxConstraintType), and [ScheduleConstraintType](@ref EnergyModelsRenewableProducers.ScheduleConstraintType). Such constraints can be used to, for example, enforce minimum discharge due to environmental considerations. The constraints values are relative to the gate capacity.

### [Additional fields](@id nodes-hydro_gate-fields-new)
[`HydroGate`](@ref) includes a `resource::Resource` field instead of the `Input` and `Output` fields as a a hydro gate can only have one resource type, water, and the scaling is always 1 since water does not arise or disappear.

## [Mathematical description](@id nodes-hydro_gate-math)
The [`HydroGate`](@ref) inherits its mathematical description from the [NetworkNode](@extref EnergyModelsBase.NetworkNode) where there is only a single input and output resource given by the `resource` field and scaling 1.

### [Variables](@id nodes-hydro_gate-math-var)

#### [Standard variables](@id nodes-hydro_gate-math-var-stand)
The [`HydroGate`](@ref) utilizes the standard variables from the `NetworkNode`, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*.
The variables that are used in the additional constraints are:

#### [Additional variables](@id nodes-hydro_gate-math-add)
- ``\texttt{gate\_disch\_penalty\_up}[n, t]``: Variable for penalizing violation of the discharge constraint in direction up in `HydroGate` node ``n`` in operational period ``t`` with unit volume per time unit.
- ``\texttt{gate\_disch\_penalty\_down}[n, t]``: Variable for penalizing violation of the discharge constraint in direction down in `HydroGate` node ``n`` in operational period ``t`` with unit volume per time unit.

### [Constraints](@id nodes-hydro_gate-math-con)
The following sections omit the direct inclusion of the vector of `HydroGate` nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroGate`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods). The ``\texttt{gate\_disch\_penalty\_up}[n, t]`` and ``\texttt{gate\_disch\_penalty\_down}[n, t]`` variables are only added if required in a constraint, where ``c_{up}`` denotes constraint requiring up penalty, and ``c_{down}`` denotes constraint requiring down penalty.

#### [Standard constraints](@id nodes-hydro_gate-math-con-stand)
`HydroGate` nodes utilize in general the standard constraints described in *[Constraint functions for `NetworkNode`](@extref EnergyModelsBase nodes-network_node-math-con)*. In addition, it includes the penalty variables when required for constraints when dispatching `constraints_opex_var`:
```math
\begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\
    \sum_{t \in t_{inv}} \Big( &opex\_var(n, t) \times \texttt{cap\_use}[n, t] + \\&
    penalty(c_{up}, t) \times \texttt{gate\_disch\_penalty\_up}[n, t] + \\&
    penalty(c_{down}, t) \times \texttt{gate\_disch\_penalty\_down}[n, t] \Big) \times scale\_op\_sp(t_{inv}, t)
\end{aligned}
```

#### [Additional constraints](@id nodes-hydro_gate-math-con-add)
The `HydroGate` nodes utilize the majority of the concepts from [NetworkNode](@extref EnergyModelsBase nodes-network_node-math-con) but require adjustments for both constraining the variable ``\texttt{flow\_out}``. This is achieved through dispatching the function `constraints_flow_out` by adding

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
    \texttt{flow\_out}&[n, t, p] + \texttt{gate\_disch\_penalty\_up}[n, t] \geq \\ &
        capacity(n, t) \times value(c, t) \\
    \texttt{flow\_out}&[n, t, p] - \texttt{gate\_disch\_penalty\_down}[n, t] \leq \\ &
        capacity(n, t) \times value(c, t) \\
    \texttt{flow\_out}&[n, t, p] + \texttt{gate\_disch\_penalty\_up}[n, t] - \texttt{gate\_disch\_penalty\_down}[n, t] = \\&
        capacity(n, t) \times value(c, t)
\end{aligned}
```
