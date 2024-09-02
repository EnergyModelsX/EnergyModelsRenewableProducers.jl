# [CO₂ storage node](@id nodes-hydro_power)

The reference storage node, [`RefStorage`](@extref EnergyModelsBase.RefStorage) is quite flexible with respect to the individual storage behaviours, that is cyclic (both representative and strategic) or accumulating as it is included as parametric type using the individual *[storage behaviours](@extref EnergyModelsBase lib-pub-nodes-stor_behav)*.
In addition, it allows for both charge and level different *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)*.
It is however not possible at the moment to provide a discharge capacity required in hydropower modelling.
Furthermore, it is not possible to include an inflow to the storage node, except through artifically creating a source node representing the water flowing into the node.

Hence, it is necessary to include specific hydropower storage node

## [Introduced type and its field](@id nodes-hydro_power-fields)

The [`HydroStorage`](@ref) abstract type is used to simplify the design of the constraints.
It has in its current stage two concrete subtypes, [`HydroStor`](@ref) and [`PumpedHydroStor`](@ref).
Both types utilize the same main functionality, although [`PumpedHydroStor`](@ref) allows for utilizing electricity to store more water.
The two nodes are designed to work with the cyclic *[storage behaviors](@extref EnergyModelsBase lib-pub-nodes-stor_behav)*.

!!! warning "Input, output, and stored resource"
    Although hydro reservoir store water, we have to assume in the current implementation that electricity is stored.
    The key reason for this is that we do not support in the modelling approach a conversion from the variable ``\texttt{flow\_in}`` of a resource to a different stored resource.

### [Standard fields](@id nodes-hydro_power-fields-stand)

The standard fields are given as:

- **`id`**:\
  The field **`id`** is only used for providing a name to the node. This is similar to the approach utilized in `EnergyModelsBase`.
- **`charge::EMB.UnionCapacity`**:\
  The charge storage parameters must include a capacity for charging.
  More information can be found on *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)*.
  !!! info "Meaning in boths nodes"
      The `charge` field is only included for [`PumpedHydroStor`](@ref) nodes while [`HydroStor`](@ref) do **not** allow for flow into the node.
- **`level::EMB.UnionCapacity`**:\
  The level storage parameters must include a capacity for charging.
  More information can be found on *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)*.
- **`charge::EMB.UnionCapacity`**:\
  The charge storage parameters must include a capacity for charging.
  More information can be found on *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)*.
  !!! note "Permitted values for storage parameters in `charge`, `level`, and `discharge`"
      If the node should contain investments through the application of [`EnergyModelsInvestments`](https:// energymodelsx.github.io/EnergyModelsInvestments.jl/stable/), it is important to note that you can only use `FixedProfile` or `StrategicProfile` for the capacity, but not `RepresentativeProfile` or `OperationalProfile`.
      Similarly, you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
      The variable operating expenses can be provided as `OperationalProfile` as well.
      In addition, all capacity and fixed OPEX values have to be non-negative.
- **`stor_res::ResourceEmit`**:\
  The `stor_res` is the stored [`Resource`](@extref EnergyModelsBase.Resource).
  The current implementation of `HydroStorage` nodes do not consider the conversion of potential energy of the stored water to electricity.
  Hence, you must specifiy your *electricity* resource.
- **`input::Dict{<:Resource, <:Real}`** and **`output::Dict{<:Resource, <:Real}`**:\
  Both fields describe the `input` and `output` [`Resource`](@extref EnergyModelsBase.Resource)s with their corresponding conversion factors as dictionaries.
  The values correspond to charge and discharge efficiencies from the `HydroStorage` nodes.\
  All values have to be in the range ``[0, 1]``.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.
  In the current version, it is only relevant for additional investment data when [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) is used.

### [Additional fields](@id nodes-hydro_power-fields-new)

[`HydroStorage`](@ref) nodes add additional fields compared to [`RefStorage`](@extref EnergyModelsBase.RefStorage) nodes.
These fields are located below the field `discharge`, and hence, correspond to the 4ᵗʰ to 6ᵗʰ fields of the node.
As a consequence, `stor_res` is now the 7ᵗʰ field compared to being the 4ᵗʰ in a [`RefStorage`](@extref EnergyModelsBase.RefStorage) node.

The individual fields are related to specifics of hydropower.
These fields are given as:

- **`level_init::TimeProfile`**:\
  The initial level corresponds to the amount of *electricity* stored in the reservoir at the beginning of each strategic period.
  It can be provided as `OperationalProfile`.
  In practice, it is however sufficient to provide it as `StrategicProfile` as only a single value is used.\
  The initial levels have to be non-negative and less than the maximum storage capacity.
- **`level_inflow::TimeProfile`**:\
  The inflow is representing the potential *electricity* flowing into the reservoir in each operational period.
  It is depending on rivers flowing into the reservoir or rainfall.
  It can be provided as `OperationalProfile`.
- **`level_min::TimeProfile`**:\
  The minimum level provides a lower bound on the usage of the storage node in each operational period.
  This lower bound can be enforced by regulators to maintain a minimum amount of available stored electricity.
  The current implementation does not allow for a violation of the constraint, although this can be implemented in a latter stage.
  It can be provided as `OperationalProfile`.\
  The inflow has to be able in combination with the initial level to provide the required minimum level in the first operational period of each strategic period.
  In addition, all values have to be in the range ``[0, 1]``.

## [Mathematical description](@id nodes-hydro_power-math)

In the following mathematical equations, we use the name for variables and functions used in the model.
Variables are in general represented as

``\texttt{var\_example}[index_1, index_2]``

with square brackets, while functions are represented as

``func\_example(index_1, index_2)``

with paranthesis.

### [Variables](@id nodes-hydro_power-math-var)

#### [Standard variables](@id nodes-hydro_power-math-var-stand)

The hydro power node types utilize all standard variables from `RefStorage`, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*.
The variables include:

- [``\texttt{opex\_var}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{stor\_level}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_level\_inst}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_charge\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_charge\_inst}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_discharge\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_discharge\_inst}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{flow\_in}``](@extref EnergyModelsBase man-opt_var-flow)
- [``\texttt{flow\_out}``](@extref EnergyModelsBase man-opt_var-flow)
- [``\texttt{stor\_level\_Δ\_op}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_level\_Δ\_rp}``](@extref EnergyModelsBase man-opt_var-cap) if the `TimeStruct` includes `RepresentativePeriods`
- [``\texttt{emissions\_node}``](@extref EnergyModelsBase man-opt_var-emissions)

The variables ``\texttt{flow\_in}`` and ``\texttt{stor\_charge\_use}`` are fixed to a value of 0 in the function `constraints_flow_in` for [`HydroStor`](@ref) nodes as these nodes correspond to regulated hydropower plants and not pumped hydropower plants..

#### [Additional variables](@id nodes-hydro_power-math-add)

[`HydroStorage`](@ref) nodes must allow for spillage of surplus stored water.
Hence, a single additional variable is declared through dispatching on the method [`EnergyModelsBase.variables_node()`](@ref):

- ``\texttt{hydro\_spill}[n, t]``: Spilled *electricity* in hydropower node ``n`` in operational period ``t`` with a typical unit of MW.\
  The spillage in each operational period is a rate specifying how much *electricity* is spilled, that is not routed the the grid, but instead directed from the turbines to avoid overfilling the reservoir.
  It hence allows for an overflow from a reservoir if the inflow to a reservoir exceeds its capacity and the outflow through power generation.

### [Constraints](@id nodes-hydro_power-math-con)

The following sections omit the direct inclusion of the vector of hydropower storage nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroStor`](@ref) or [`PumpedHydroStor`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods).

#### [Standard constraints](@id nodes-hydro_power-math-con-stand)

Hydropower storages nodes utilize in general the standard constraints described on *[Constraint functions](@extref EnergyModelsBase man-con)* for `RefStorage` nodes.

!!! warning "stor_charge_xxx"
    The constraints for ``\texttt{stor\_charge\_use}`` are only implemented for [`PumpedHydroStor`](@ref) nodes.
    This includes as well the contribution to the variables ``\texttt{opex\_fixed}`` and ``\texttt{opex\_var}``.

These standard constraints are:

- `constraints_capacity`:

  ```math
  \begin{aligned}
  \texttt{stor\_level\_inst}[n, t] & \geq \texttt{stor\_level}[n, t] \\
  \texttt{stor\_charge\_inst}[n, t] & \geq \texttt{stor\_charge\_use}[n, t] \\
  \texttt{stor\_discharge\_inst}[n, t] & \geq \texttt{stor\_discharge\_use}[n, t] \\
  \end{aligned}
  ```

- `constraints_capacity_installed`:

  ```math
  \begin{aligned}
  \texttt{stor\_level\_inst}[n, t] & = capacity(level(n), t) \\
  \texttt{stor\_charge\_inst}[n, t] & = capacity(charge(n), t) \\
  \texttt{stor\_discharge\_inst}[n, t] & = capacity(charge(n), t)
  \end{aligned}
  ```

  !!! tip "Using investments"
      The function `constraints_capacity_installed` is also used in [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) to incorporate the potential for investment.
      Nodes with investments are then no longer constrained by the parameter capacity.

- `constraints_level`:
  The level constraints are in general following the default approach with minor modifications.
  They are explained in detail below in *[Level constraints](@ref nodes-hydro_power-math-con-add-level)*.

- `constraints_opex_fixed`:

  ```math
  \begin{aligned}
  \texttt{opex\_fixed}&[n, t_{inv}] = \\ &
    opex\_fixed(level(n), t_{inv}) \times \texttt{stor\_level\_inst}[n, first(t_{inv})] + \\ &
    opex\_fixed(charge(n), t_{inv}) \times \texttt{stor\_charge\_inst}[n, first(t_{inv})] + \\ &
    opex\_fixed(discharge(n), t_{inv}) \times \texttt{stor\_discharge\_inst}[n, first(t_{inv})]
  \end{aligned}
  ```

  !!! tip "Why do we use `first()`"
      The variables ``\texttt{stor\_level\_inst}`` are declared over all operational periods (see the section on *[Capacity variables](@extref EnergyModelsBase man-opt_var-cap)* for further explanations).
      Hence, we use the function ``first(t_{inv})`` to retrieve the installed capacities in the first operational period of a given strategic period ``t_{inv}`` in the function `constraints_opex_fixed`.

- `constraints_opex_var`:

  ```math
  \begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\ \sum_{t \in t_{inv}}&
    opex\_var(level(n), t) \times \texttt{stor\_level}[n, t] \times EMB.multiple(t_{inv}, t) + \\ &
    opex\_var(charge(n), t) \times \texttt{stor\_charge\_use}[n, t] \times EMB.multiple(t_{inv}, t) + \\ &
    opex\_var(discharge(n), t) \times \texttt{stor\_discharge\_use}[n, t] \times EMB.multiple(t_{inv}, t)
  \end{aligned}
  ```

  !!! tip "The function `EMB.multiple`"
      The function [``EMB.multiple(t_{inv}, t)``](@extref EnergyModelsBase.multiple) calculates the scaling factor between operational and strategic periods.
      It also takes into accoun potential operational scenarios and their probability as well as representative periods.

- `constraints_data`:\
  This function is only called for specified data of the CO₂ storage node, see above.

!!! info "Implementation of OPEX"
    The fixed and variable OPEX constribubtion for the level and the charge capacities are only included if the corresponding *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)* have a field `opex_fixed` and `opex_var`, respectively.
    Otherwise, they are omitted.

The function `constraints_flow_in` is extended with a new method for hydropower nodes to differentiate whether the node is a pumped hydropower node or not.
The standard constraints given by

```math
\begin{aligned}
\texttt{stor\_level\_inst}[n, t] & \geq \texttt{stor\_level}[n, t] \\
\texttt{stor\_charge\_inst}[n, t] & \geq \texttt{stor\_charge\_use}[n, t] \\
\end{aligned}
```

are extended with a constraint for [`PumpedHydroStor`](@ref) nodes given by

```math
\texttt{flow\_in}[n, t, p] \times inputs(n, p)  =
\texttt{stor\_charge\_use}[n, t]  \qquad \forall p \in inputs(n)
```

while the variables ``\texttt{flow\_in}`` and ``\texttt{stor\_charge\_use}`` are fixed to a value of 0 for [`HydroStor`](@ref) nodes.

These constraints allow either to include an efficiency for filling the reservoir ([`PumpedHydroStor`](@ref)) or avoiding unconstrained variables ([`HydroStor`](@ref)).

#### [Additional constraints](@id nodes-hydro_power-math-con-add)

##### [Constraints calculated in `create_node`](@id nodes-hydro_power-math-con-add-node)

The outlet flow constraints are given as

```math
\texttt{flow\_out}[n, t, p] =
\texttt{stor\_charge\_use}[n, t] \times outputs(n, p) \qquad \forall p \in outputs(n)
```

As a consequence, similar to the inlet flow constraint, we can specify an efficiency between 0 and 1 to account for loses in the turbine.

In addition a constraint on the maximum discharge given by

```math
\texttt{stor\_discharge\_use}[n, t] \leq \texttt{stor\_level}[n, t]
```

is included to constrain the discharge further.
This constraint is in practice not active as the storage level is bound at a lower bound provided through the field `level_min`.

##### [Level constraints](@id nodes-hydro_power-math-con-add-level)

The level constraints are in general slightly more complex to understand.
The overall structure is outlined on *[Constraint functions](@extref EnergyModelsBase man-con-stor_level)*.
The level constraints are called through the function `constraints_level` which then calls additional functions depending on the chosen time structure (whether it includes representative periods and/or operational scenarios) and the chosen *[storage behaviour](@extref EnergyModelsBase lib-pub-nodes-stor_behav)*.

The hydro power nodes utilize the majority of the concepts from `EnergyModelsBase` but require adjustments for both constraining the variable ``\texttt{stor\_level\_Δ\_op}`` and specifying how the storage node has to behave in the first operational period of a strategic period.
This is achieved through dispatching on the functions `constraints_level_aux`.

The constraints introduced in `constraints_level_aux`  can be divided in three groups:

1. the energy balance,

   ```math
   \begin{aligned}
     \texttt{stor\_level\_Δ\_op}&[n, t] = \\ &
     level\_inflow(n, t) + \texttt{stor\_charge\_use}[n, t] - \\ &
     \texttt{stor\_discharge\_use}[n, t] - \texttt{hydro\_spill}[n, t]
   \end{aligned}
   ```

2. the initial storage level in the first operational period of a strategic period, and

   ```math
   \begin{aligned}
     \texttt{stor\_level}& [n, first(t_{inv})] = \\ &
     level\_init(n, first(t_{inv})) + \\ &
     \texttt{stor\_level\_Δ\_op}[n, first(t_{inv})] \times duration(first(t_{inv}))
   \end{aligned}
   ```

3. the minimum level constraint

   ```math
   \texttt{stor\_level}[n, t] \geq level\_min(n, t) \times \texttt{stor\_level\_inst}[n, t]
   ```

corresponding to the change in the storage level in an operational period and strategic period, respectively.

If the time structure includes representative periods, we also calculate the change of the storage level in each representative period within the function `constraints_level_iterate` (from `EnergyModelsBase`):

```math
  \texttt{stor\_level\_Δ\_rp}[n, t_{rp}] = \sum_{t \in t_{rp}}
  \texttt{stor\_level\_Δ\_op}[n, t] \times EMB.multiple(t_{rp}, t)
```

The general level constraint is calculated in the function `constraints_level_iterate` (from `EnergyModelsBase`):

```math
\texttt{stor\_level}[n, t] = prev\_level +
\texttt{stor\_level\_Δ\_op}[n, t] \times duration(t)
```

in which the value ``prev\_level`` is depending on the type of the previous operational (``t_{prev}``) and strategic level (``t_{inv,prev}``) (as well as the previous representative period (``t_{rp,prev}``)).
It is calculated through the function `previous_level`.

In the case of hydropower node, we can distinguish the following cases:

1. The first operational period in the first representative period in any strategic period (given by ``typeof(t_{prev}) = typeof(t_{rp, prev})`` and ``typeof(t_{inv,prev}) = NothingPeriod``).
   In this situation, we can distinguish three cases, the time structure does not include representative periods:

   ```math
   prev\_level = \texttt{stor\_level}[n, last(t_{inv})]
   ```

   the time structure includes representative periods and the storage behavior is given as [`CyclicRepresentative`](@extref EnergyModelsBase.CyclicRepresentative):

   ```math
   prev\_level = \texttt{stor\_level}[n, last(t_{rp})]
   ```

   the time structure includes representative periods and the storage behavior is given as [`CyclicStrategic`](@extref EnergyModelsBase.CyclicStrategic):

   ```math
   \begin{aligned}
    prev\_level = & \texttt{stor\_level}[n, first(t_{rp,last})] - \\ &
      \texttt{stor\_level\_Δ\_op}[n, first(t_{rp,last})] \times duration(first(t_{rp,last})) + \\ &
      \texttt{stor\_level\_Δ\_rp}[n, t_{rp,last}] \times duration\_strat(t_{rp,last})
   \end{aligned}
   ```

2. The first operational period in subsequent representative periods in any strategic period (given by ``typeof(t_{prev}) = nothing``) f the the storage behavior is given as [`CyclicStrategic`](@extref EnergyModelsBase.CyclicStrategic):\

   ```math
   \begin{aligned}
    prev\_level = & \texttt{stor\_level}[n, first(t_{rp,prev})] - \\ &
      \texttt{stor\_level\_Δ\_op}[n, first(t_{rp,prev})] \times duration(first(t_{rp,prev})) + \\ &
      \texttt{stor\_level\_Δ\_rp}[n, t_{rp,prev}]
   \end{aligned}
   ```

   This situation only occurs in cases in which the time structure includes representative periods.

3. All other operational periods:\

   ```math
    prev\_level = \texttt{stor\_level}[n, t_{prev}]
   ```

All cases are implemented in `EnergyModelsBase` simplifying the design of the system.
