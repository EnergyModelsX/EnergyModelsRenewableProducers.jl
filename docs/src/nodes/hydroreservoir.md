# [Hydro reservoir node](@id nodes-hydro_reservoir)

The [`HydroReservoir`](@ref), [`HydroGate`](@ref), [`HydroGenerator`](@ref), and [`HydroPump`](@ref) should be used for detailed hydropower modeling.
Unlike [`HydroStorage`](@ref), [`HydroReservoir`](@ref) can have water as the stored resource.
[`HydroGenerator`](@ref) can produce electricity by moving water to a lower reservoir or the ocean that should be represented as a [`RefSink`](@extref EnergyModelsBase.RefSink).
Likewise, [`HydroPump`](@ref) can consume electricity by moving water to a higher reservoir.
[`HydroGate`](@ref) can discharge to lower reservoirs without producing electricity, for example due to spillage or environmental restrictions in the water course.

## [Introduced type and its field](@id nodes-hydro_reservoir-fields)
The [`HydroReservoir`](@ref) represents a water storage in a hydropower system. In its simplest form, the [`HydroGenerator`](@ref) and [`HydroPump`](@ref) can convert energy between reservoir at different head levels to electricity under the assumption that the reservoirs has constant head level. In these cases, the [`HydroReservoir`](@ref) does not require a description of the relation between volume level and head level. For more detailed modelling, this relation is required to account for the increased power output when the head level difference between reservoirs increase.

### [Standard fields](@id nodes-hydro_reservoir-fields-stand)
The standard fields are given as:

- **`id`**:\
  The field **`id`** is only used for providing a name to the node.
- **`vol::EMB.UnionCapacity`**:\
  The installed volume corresponds to the total water volume storage capacity of the reservoir.
- **`stor_res::ResourceCarrier`**:\
  The resource that is stored in the reservoir. Should be the reserource representing water and must be consistent for all components in the watercourse.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model. Could be used to add minimum, maximum and schedule constraints for the volume using [Constraint{T<:AbstractConstraintType}](@ref EnergyModelsRenewableProducers.Constraint), where [AbstractConstraintType](@ref EnergyModelsRenewableProducers.AbstractConstraintType) has subtypes [MinConstraintType](@ref EnergyModelsRenewableProducers.MinConstraintType), [MaxConstraintType](@ref EnergyModelsRenewableProducers.MaxConstraintType), and [ScheduleConstraintType](@ref EnergyModelsRenewableProducers.ScheduleConstraintType).
    
### [Additional fields](@id nodes-hydro_reservoir-fields-new)

[`HydroReservoir`](@ref) nodes add a single additional field compared to a [`RefStorage`](@extref EnergyModelsBase.RefStorage), and does not include the `charge` field since charge/discharge capacity is given throug the [`HydroGenerator`](@ref), [`HydroPump`](@ref), and [`HydroGate`](@ref):

- **`vol_inflow::TimeProfile`**:\
  The volume inflow to the reservoir per timestep.

## [Mathematical description](@id nodes-hydro_reservoir-math)

The mathematical description is similar to the [`RefStorage`](@extref EnergyModelsBase.RefStorage) except the inflow is added to the storage balance.

### [Variables](@id nodes-hydro_reservoir-math-var)

#### [Standard variables](@id nodes-hydro_reservoir-math-var-stand)
The hydro power node types utilize all standard variables from `RefStorage`, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*.
The variables that are used in the additional constraints are:

- [``\texttt{stor\_level}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_level\_Δ\_op}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_charge\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_discharge\_use}``](@extref EnergyModelsBase man-opt_var-cap)

#### [Additional variables](@id nodes-hydro_reservoir-math-add)
- ``\texttt{rsv\_vol\_penalty\_up}[n, t]``: Variable for penalizing violation of the volume constraint in direction up in `HydroReservoir` node ``n`` in operational period ``t`` with a typical unit of ``Mm^3``.
- ``\texttt{rsv\_vol\_penalty\_down}[n, t]``: Variable for penalizing violation of the volume constraint in direction down in `HydroReservoir` node ``n`` in operational period ``t`` with a typical unit of ``Mm^3``.

### [Constraints](@id nodes-hydro_reservoir-math-con)
The following sections omit the direct inclusion of the vector of `HydroReservoir` nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroGate`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods). The ``\texttt{rsv\_vol\_penalty\_up}[n, t]`` and ``\texttt{rsv\_vol\_penalty\_down}[n, t]`` variables are only added if required in a constraint, where ``c_{up}`` denotes constraint requiring up penalty, and ``c_{down}`` denotes constraint requiring down penalty.

#### [Standard constraints](@id nodes-hydro_reservoir-math-con-stand)
`HydroReservoir` nodes utilize in general the standard constraints described in *[Constraint functions for `Storage` nodes](@extref EnergyModelsBase nodes-storage-math-con)*. In addition, it includes the penalty variables when required for constraints when dispatching `constraints_opex_var`:
```math
\begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\ \sum_{t \in t_{inv}} \Big( &
    opex\_var(level(n), t) \times \texttt{stor\_level}[n, t] + \\ &
    opex\_var(charge(n), t) \times \texttt{stor\_charge\_use}[n, t] + \\ &
    opex\_var(discharge(n), t) \times \texttt{stor\_discharge\_use}[n, t] \\&
    penalty(c_{up}, t) \times \texttt{rsv\_vol\_penalty\_up}[n, t]+ \\&
    penalty(c_{down}, t) \times \texttt{rsv\_vol\_penalty\_down}[n, t] \Big) \times scale\_op\_sp(t_{inv}, t) 
\end{aligned}
```


#### [Additional constraints](@id nodes-hydro_reservoir-math-con-add)
The `HydroReservoir` nodes utilize the majority of the concepts from `EnergyModelsBase` but require adjustments for both constraining the variables ``\texttt{stor\_level\_Δ\_op}`` and ``\texttt{stor\_level}``.
This is achieved through dispatching on the functions `constraints_level_aux` through altering

1. the energy balance to include hydro inflow,

   ```math
   \begin{aligned}
     \texttt{stor\_level\_Δ\_op}&[n, t] = \\ &
       \texttt{vol\_inflow}(n, t) + \texttt{stor\_charge\_use}[n, t] - \texttt{stor\_discharge\_use}[n, t]
   \end{aligned}
   ```

2. the level constraints if additional constraints exist on the `Data` field,

   ```math
   \begin{aligned}
     \texttt{stor\_level}&[n, t] \geq capacity(level(n), t) * value(c, t) \\
     \texttt{stor\_level}&[n, t] \leq capacity(level(n), t) * value(c, t) \\
     \texttt{stor\_level}&[n, t] = capacity(level(n), t) * value(c, t)
   \end{aligned}
   ```

3. the level constraints with penalty if the constraints has non-infinite penalty value.

   ```math
   \begin{aligned}
     \texttt{stor\_level}&[n, t] + \texttt{rsv\_vol\_penalty\_up}[n, t] \geq \\&
       capacity(level(n), t) * value(c, t) \\
     \texttt{stor\_level}&[n, t] - \texttt{rsv\_vol\_penalty\_down}[n, t] \leq \\&
       capacity(level(n), t) * value(c, t) \\
     \texttt{stor\_level}&[n, t] + \texttt{rsv\_vol\_penalty\_up}[n, t] - \texttt{rsv\_vol\_penalty\_down}[n, t] = \\&
       capacity(level(n), t) * value(c, t)
   \end{aligned}
   ```
