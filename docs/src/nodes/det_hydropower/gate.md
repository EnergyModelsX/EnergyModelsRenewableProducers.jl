# [Hydro gate node](@id nodes-det_hydro_power-gate)

## [Introduced type and its field](@id nodes-det_hydro_power-gate-fields)

The [`HydroGate`](@ref) is used when water can be released between reservoirs without going through a generator.
The [`HydroGate`](@ref) can either represent a controlled gate that is used to regulate the dispatch from a reservoir without production, or to bypass water when a reservoir is, for example, full.
The [`HydroGate`](@ref) can also be used to represent spillage.
Althoug spillage is not, in reality, a control decision but a consequence of full reservoir, it is often modelled as a controllable decisions since state dependent spillage can not be modelled directly in a linear model.
Costs for operating gates can be added to penalize unwanted spillage using the field `opex_var`.

### [Standard fields](@id nodes-det_hydro_power-gate-fields-stand)

The [`HydroGate`](@ref) nodes build on the [NetworkNode](@extref EnergyModelsBase.NetworkNode) node type. Standard fields are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
  This is similar to the approach utilized in `EnergyModelsBase`.
- **`cap::TimeProfile`**:\
  The installed gate discharge capacity.
  In the case of a `HydroGate`, this value corresponds to the maximum possible discharge without any generator.
  In practice, this value has to be sufficiently large to avoid an unfeasible system.
- **`opex_var::TimeProfile`**:\
  The variable operational expenses are based on the capacity utilization through the variable [`cap_use`](@extref EnergyModelsBase man-opt_var-cap).
  Hence, it is directly related to the specified `output` ratios.
  The variable operating expenses can be provided as `OperationalProfile` as well.
- **`opex_fixed::TimeProfile`**:\
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of a strategic period as outlined on *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS)*.\
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.
  !!! note "Additional constraints"
      The `data` field can be used to add minimum, maximum, and schedule constraints on the discharge using the general *[constraints types](@ref nodes-det_hydro_power-phil-con)*.

!!! warning "Input/output fields"
    [`HydroGate`](@ref) nodes do not utilize the fields `input` and `output` as a hydro gate can only have one resource type, water, and the conversion is always 1 due to mass conservation.

### [Additional fields](@id nodes-det_hydro_power-gate-fields-new)

[`HydroGate`](@ref) nodes a single additional field:

- **`resource::Resource`**:\
  The water resource that the node can release.

## [Mathematical description](@id nodes-det_hydro_power-gate-math)

The [`HydroGate`](@ref) inherits its mathematical description from the [NetworkNode](@extref EnergyModelsBase.NetworkNode) where there is only a single input and output resource given by the `resource` field and a conversion ratio of 1.

### [Variables](@id nodes-det_hydro_power-gate-math-var)

#### [Standard variables](@id nodes-det_hydro_power-gate-math-var-stand)

The [`HydroGate`](@ref) utilizes the standard variables from the [NetworkNode](@extref EnergyModelsBase.NetworkNode), as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*:

- [``\texttt{opex\_var}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{cap\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{cap\_inst}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{flow\_in}``](@extref EnergyModelsBase man-opt_var-flow)
- [``\texttt{flow\_out}``](@extref EnergyModelsBase man-opt_var-flow)

#### [Additional variables](@id nodes-det_hydro_power-gate-math-add)

[`HydroGate`](@ref) nodes add additional variables if required by the *[additional constraints](@ref nodes-det_hydro_power-phil-con)*:

- ``\texttt{gate\_penalty\_up}[n, t]``: Variable for penalizing violation of the discharge constraint in direction *up* in `HydroGate` node ``n`` in operational period ``t`` with unit volume per time unit.\
  *Up* implies in this case that the flow through the gate is larger than planned.
- ``\texttt{gate\_penalty\_down}[n, t]``: Variable for penalizing violation of the discharge constraint in direction *down* in `HydroGate` node ``n`` in operational period ``t`` with unit volume per time unit.\
  *Down* implies in this case that the flow through the gate is smaller than planned.

### [Constraints](@id nodes-det_hydro_power-gate-math-con)

The following sections omit the direct inclusion of the vector of [`HydroGate`](@ref) nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroGate`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods).

#### [Standard constraints](@id nodes-det_hydro_power-gate-math-con-stand)

[`HydroGate`](@ref) nodes utilize in general the standard constraints described in *[Constraint functions for `NetworkNode`](@extref EnergyModelsBase nodes-network_node-math-con)*.
The majority of these constraints are hence ommitted in the following description.

The function `constraints_opex_var` requires a new method as we have to include the penalty variables for violating the constraints if required:

```math
\begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\
    \sum_{t \in t_{inv}} \Big( &opex\_var(n, t) \times \texttt{cap\_use}[n, t] + \\ &
    penalty(c_{up}, t) \times \texttt{gate\_penalty\_up}[n, t] + \\ &
    penalty(c_{down}, t) \times \texttt{gate\_penalty\_down}[n, t] \Big) \times scale\_op\_sp(t_{inv}, t)
\end{aligned}
```

where ``penalty()`` returns the penalty value for violation in the upward and downward direction of constraints with penalty variables, denoted by ``c_{up}`` and  ``c_{up}`` respectively.

!!! tip "The function `scale_op_sp`"
    The function [``scale\_op\_sp(t_{inv}, t)``](@extref EnergyModelsBase.scale_op_sp) calculates the scaling factor between operational and strategic periods.
    It also takes into account potential operational scenarios and their probability as well as representative periods.

The method for `constraints_flow_out` adds *[discharge constraints](@ref nodes-det_hydro_power-phil-con)* if additional constraints are provided in the `Data` field. Soft constraints, *i.e.*, constraints with a penalty, are used if the constraints have non-infinite penalty values. The mathematical formualtion of the constraints are:

1. Minimum constraints for the discharge:

   ```math
   \begin{aligned}
     \texttt{flow\_out}[n, t, p] \geq & capacity(n, t) \times value(c, t) \qquad & \forall c \in C^{min}\\
     \texttt{flow\_out}[n, t, p] + & \texttt{gate\_penalty\_up}[n, t] \geq \\ &
      capacity(n, t) \times value(c, t) \qquad & \forall c \in C^{min}
   \end{aligned}
   ```

2. Maximum constraints for the discharge:

   ```math
   \begin{aligned}
     \texttt{flow\_out}[n, t, p] \leq & capacity(n, t) \times value(c, t) \qquad & \forall c \in C^{max}\\
     \texttt{flow\_out}[n, t, p] - & \texttt{gate\_penalty\_down}[n, t] \leq \\ &
      capacity(n, t) \times value(c, t) \qquad & \forall c \in C^{max}
   \end{aligned}
   ```

3. Scheduling constraints for the discharge:

   ```math
   \begin{aligned}
     \texttt{flow\_out}[n, t, p] = & capacity(n, t) \times value(c, t) \qquad & \forall c \in C^{sch}\\
     \texttt{flow\_out}[n, t, p] + & \texttt{gate\_penalty\_up}[n, t] - \texttt{gate\_penalty\_down}[n, t] =  \\ &
     capacity(n, t) \times value(c, t) \quad & \forall c \in C^{sch}
   \end{aligned}
   ```

where ``value(c,t)`` returns the relative limit of constraint `c` and  ``capacity(n,t)`` returns the installed capacity of node `n`.
The sets ``C^{min}``,``C^{max}`` and ``C^{sch}`` contain additional minimum, maximum, and scheduling constraints, repectively.

#### [Additional constraints](@id nodes-gate-math-con-add)

The `HydroGate` nodes do not include any additional constraints other than through dispatching on *[Constraint functions for `NetworkNode` nodes](@extref EnergyModelsBase nodes-storage-math-con)* as described above.
