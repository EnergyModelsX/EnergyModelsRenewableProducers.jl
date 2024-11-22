# [Hydro reservoir node](@id nodes-det_hydro_power-reservoir)

## [Introduced type and its field](@id nodes-det_hydro_power-reservoir-fields)

The [`HydroReservoir`](@ref) nodes represents a water storage in a hydropower system.
In its simplest form, the [`HydroGenerator`](@ref) and [`HydroPump`](@ref) can convert potential energy between [`HydroReservoir`](@ref) nodes at different head levels to electricity, under the assumption that the reservoirs have constant head levels.
In these cases, the [`HydroReservoir`](@ref) node does not require a description of the relation between volume level and head level.
For more detailed modelling, this relation is required to account for the increased power output when the head level difference between reservoirs increase. Head-dependencies are currently not implemented.

!!! warning "Spillage"
    The [`HydroReservoir`](@ref) nodes do not include a spillage variable. To avoid infeasible solutions, all reservoir nodes should be connected to a [`HydroGate`](@ref) node representing a water way for spillage in case of full reservoirs.

### [Standard fields](@id nodes-det_hydro_power-reservoir-fields-stand)

The [`HydroReservoir`](@ref) nodes builds on the [`RefStorage`](@extref EnergyModelsBase.RefStorage) node type. The tandard fields are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
  This is similar to the approach utilized in `EnergyModelsBase`.
- **`vol::EMB.UnionCapacity`**:\
  The installed volume corresponds to the total water volume storage capacity of the reservoir.
  It is equivalent to the field `level` in a [`RefStorage`](@extref EnergyModelsBase.RefStorage) node.
  !!! tip "Change of name"
      The storage field level is renamed as a hydro reservoir is described by both the level (the height of the water column in the reservoir) and the storage volume (the volume of water stored).
      This results in consistency in terminology with existing hydro power models.
- **`stor_res::ResourceCarrier`**:\
  The resource that is stored in the reservoir.
  This **must** be the reserource representing water.
  The resource **must** consistent for all components in the watercourse.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.
  !!! note "Additional constraints"
      The `data` field can be used to add minimum, maximum, and schedule constraints on the storage volume using the general *[constraints types](@ref nodes-det_hydro_power-phil-con)*.

### [Additional fields](@id nodes-det_hydro_power-reservoir-fields-new)

[`HydroReservoir`](@ref) nodes add a single additional field compared to a [`RefStorage`](@extref EnergyModelsBase.RefStorage), and does not include the `charge` field since charge/discharge capacity is given through the [`HydroGenerator`](@ref), [`HydroPump`](@ref), and [`HydroGate`](@ref):

- **`vol_inflow::TimeProfile`**:\
  The water inflow rate to the reservoir.
  The inflow is representing the potential *water* flowing into the reservoir in each operational period.
  It is depending on rivers flowing into the reservoir or rainfall.
  It can be provided as `OperationalProfile`.

## [Mathematical description](@id nodes-det_hydro_power-reservoir-math)

The mathematical description is similar to the [`RefStorage`](@extref EnergyModelsBase.RefStorage) nodes except that the inflow is added to the storage balance.

### [Variables](@id nodes-det_hydro_power-reservoir-math-var)

#### [Standard variables](@id nodes-det_hydro_power-reservoir-math-var-stand)

[`HydroReservoir`](@ref) nodes utilize all standard variables from [`RefStorage`](@extref EnergyModelsBase.RefStorage), as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*.

- [``\texttt{opex\_var}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{stor\_level}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_level\_inst}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_charge\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_discharge\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{flow\_in}``](@extref EnergyModelsBase man-opt_var-flow)
- [``\texttt{flow\_out}``](@extref EnergyModelsBase man-opt_var-flow)
- [``\texttt{stor\_level\_Δ\_op}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_level\_Δ\_rp}``](@extref EnergyModelsBase man-opt_var-cap) if the `TimeStruct` includes `RepresentativePeriods`

It will however not use the vaeriables ``\texttt{stor\_charge\_inst}`` and ``\texttt{stor\_discharge\_inst}`` as the charge and discharge capacities are handled by the connected [`HydroGenerator`](@ref), [`HydroPump`](@ref), and [`HydroGate`](@ref).

#### [Additional variables](@id nodes-det_hydro_power-reservoir-math-add)

[`HydroReservoir`](@ref) nodes add additional variables if required by the *[additional constraints](@ref nodes-det_hydro_power-phil-con)*:

- ``\texttt{rsv\_vol\_penalty\_up}[n, t]``: Variable for penalizing violation of the volume constraint in direction *up* in `HydroReservoir` node ``n`` in operational period ``t`` with a typical unit of ``Mm^3``.\
  *Up* implies in this case that the reservoir volume is larger than planned.
- ``\texttt{rsv\_vol\_penalty\_down}[n, t]``: Variable for penalizing violation of the volume constraint in direction *down* in `HydroReservoir` node ``n`` in operational period ``t`` with a typical unit of ``Mm^3``.\
  *Down* implies in this case that the reservoir volume is smaller than planned.

### [Constraints](@id nodes-det_hydro_power-reservoir-math-con)

The following sections omit the direct inclusion of the vector of [`HydroReservoir`](@ref) nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroReservoir`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods).

#### [Standard constraints](@id nodes-det_hydro_power-reservoir-math-con-stand)

[`HydroReservoir`](@ref) nodes utilize in general the standard constraints described in *[Constraint functions for `Storage` nodes](@extref EnergyModelsBase nodes-storage-math-con)*.
The majority of these constraints are hence ommitted in the following description.
Specifically, the *[level constraints](@extref EnergyModelsBase nodes-storage-math-con-level)* are created using the same functions.

The function `constraints_opex_var` requires a new method as we have to include the penalty variables for violating the constraints if required:

```math
\begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\
    \sum_{t \in t_{inv}} \Big( & opex\_var(level(n), t) \times \texttt{stor\_level}[n, t] + \\ &
    opex\_var(charge(n), t) \times \texttt{stor\_charge\_use}[n, t] + \\ &
    opex\_var(discharge(n), t) \times \texttt{stor\_discharge\_use}[n, t] \\ &
    penalty(c_{up}, t) \times \texttt{rsv\_vol\_penalty\_up}[n, t]+ \\ &
    penalty(c_{down}, t) \times \texttt{rsv\_vol\_penalty\_down}[n, t] \Big) \times scale\_op\_sp(t_{inv}, t)
\end{aligned}
```

where ``penalty()`` returns the penalty value for violation of constraints with penalty variables in the upward and downward direction, denoted by ``c_{up}`` and  ``c_{down}``.

!!! tip "The function `scale_op_sp`"
    The function [``scale\_op\_sp(t_{inv}, t)``](@extref EnergyModelsBase.scale_op_sp) calculates the scaling factor between operational and strategic periods.
    It also takes into account potential operational scenarios and their probability as well as representative periods.

The energy balance in `constraints_level_aux` is altered to include the inflow to the reservoir:

```math
\begin{aligned}
  \texttt{stor\_level\_Δ\_op}&[n, t] = \\ &
  vol\_inflow(n, t) + \texttt{stor\_charge\_use}[n, t] - \texttt{stor\_discharge\_use}[n, t]
\end{aligned}
```

The new method adds furthermore *[additional constraints](@ref nodes-det_hydro_power-phil-con)*, if the corresponding types are provided in the `Data` field.
Soft constraints, *i.e.*, constraints with a penalty, are used if the constraints have non-infinite penalty values.
The mathematical formulation of the constraints are:

1. Minumum constraints for the reservoir level:

   ```math
   \begin{aligned}
      \texttt{stor\_level}[n, t] \geq & capacity(level(n), t) \times value(c, t) \qquad & \forall c \in C^{min} \\
      \texttt{stor\_level}[n, t] + & \texttt{rsv\_vol\_penalty\_up}[n, t] \geq \\ &
      capacity(level(n), t) * value(c, t) \qquad & \forall c \in C^{min}
   \end{aligned}
   ```

2. Maximum constraints for the reservoir level:

   ```math
   \begin{aligned}
    \texttt{stor\_level}[n, t] \leq & capacity(level(n), t) \times value(c, t) \qquad & \forall c \in C^{max} \\
    \texttt{stor\_level}[n, t] - & \texttt{rsv\_vol\_penalty\_down}[n, t] \leq \\ &
    capacity(level(n), t) \times value(c, t) \qquad & \forall c \in C^{max}
   \end{aligned}
   ```

3. Scheduling constraints for the reservoir level:

   ```math
   \begin{aligned}
    \texttt{stor\_level}[n, t] = & capacity(level(n), t) \times value(c, t) \quad & \forall c \in C^{sch} \\
    \texttt{stor\_level}[n, t] + & \texttt{rsv\_vol\_penalty\_up}[n, t] - \texttt{rsv\_vol\_penalty\_down}[n, t] = \\ &
    capacity(level(n), t) \times value(c, t) \quad & \forall c \in C^{sch} \\
   \end{aligned}
   ```

where ``value(c,t)`` returns the relative limit of constraint `c` and  ``capacity(n,t)`` returns the installed capacity of node `n`.
The sets ``C^{min}``,``C^{max}`` and ``C^{sch}`` contain additional minimum, maximum, and scheduling constraints, repectively.

#### [Additional constraints](@id nodes-det_hydro_power-reservoir-math-con-add)

The `HydroReservoir` nodes do not include any additional constraints other than through dispatching on *[Constraint functions for `Storage` nodes](@extref EnergyModelsBase nodes-storage-math-con)* as described above.
