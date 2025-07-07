# [Battery nodes](@id nodes-battery)

As outlined in the section on *[simple hydro storage](@ref nodes-hydro_power)*, the reference storage node[`RefStorage`](@extref EnergyModelsBase.RefStorage) has some built in limitations.
In the case of battery storage, the main limitations are related to not limiting the discharge use, not being able to include charge and discharge efficiencies, and not allowing for degradation of the storage capacity.

Hence, it is necessary to include specific battery nodes.

## [Concepts used for Batteries](@id nodes-battery-phil)

### [Battery lifetime](@id nodes-battery-phil-life)

Batteries experience storage capacity degradation.
The degradation can be differentiated in 1. degradation through time and 2. degradation through charging and discharging the battery.
Degradation through time is not included in the developed nodes.
Instead, degradation through charging is included.

The lifetime is implemented through [`AbstractBatteryLife`](@ref EnergyModelsRenewableProducers.AbstractBatteryLife) types.
There are two options implemented, [`InfLife`](@ref) and [`CycleLife`](@ref).
[`InfLife`](@ref) does not include any storage capacity degradation.
The battery life is unlimited and unimpacted by the use of the battery.
[`CycleLife`](@ref) includes both linear battery degradation and a lifetime through the maximum number of cycles of the battery.
The linear degradation is dependent on the charging of the battery although this is equivalent to the discharging.
The type allows for replacement of the battery stack to reduce battery degradation to 0 at the beginning of an investment period.
The cost for replacement has to be accessible through a strategic period.
Hence, it can be either a `FixedProfile` or a `StrategicProfile`, but cannot include, *e.g.* `OperationalProfile`.

!!! danger "Varying storage capacities with Batteries"
    If you use batteries with varying capacities, it is important to implement one battery node for each investment period.
    The key reason is that the use is not calculated based on changing capacities.
    Similarly, if you plan to use batteries in investment models, it is necessary to specify one battery node for each investment periods with limited investments in an investment period.

### [Philosophy of `ReserveBattery`](@id nodes-battery-phil-reserve)

[`ReserveBattery`](@ref) nodes allow modelling a system that requires reserve capacity.
The reserve capacity must be specified as a sink with a demand for a given reserve resource and a potential penalty for violating the demand.
The [`ReserveBattery`](@ref) is subsequently coupled to the link to satisfy the potential demand.

Reserve resources and demands are not included in the energy balances.
Instead, they can be used to specify a minimum amount of dispatchable power to both increase either the electricity generation capacity or the electricity demand.

## [Introduced types and their fields](@id nodes-battery-fields)

The [`AbstractBattery`](@ref) abstract type is used to simplify the design of the constraints.
It has in its current stage two concrete subtypes, [`Battery`](@ref) and [`ReserveBattery`](@ref).
Both types utilize the same main functionality with respect to efficiencies and battery lifes.
[`ReserveBattery`](@ref) is included as a first nodal type to be able to provide a reserve capacity for the energy system.
This allows the user to specify a minimum of required reserve capacity at each individual operational period.

The two nodes are designed to work with the cyclic *[storage behaviors](@extref EnergyModelsBase lib-pub-nodes-stor_behav)*.
In practice, battery storages should utilize [`CyclicRepresentative`](@extref EnergyModelsBase.CyclicRepresentative) as battery storage is in general not considered for seasonal energy storage.

### [Standard fields](@id nodes-battery-fields-stand)

The standard fields are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node. This is similar to the approach utilized in `EnergyModelsBase`.
- **`charge::EMB.UnionCapacity`**:\
  The charge storage parameters must include a capacity.
  The charge capacity is the capacity **before** taking into account the charging efficiency from the viewpoint of the storage level.
  This is also shown in the section on the *[level constraints](@ref nodes-battery-math-con-add-level)*
  More information can be found on *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)*.
- **`level::EMB.UnionCapacity`**:\
  The level storage parameters must include a capacity.
  More information can be found on *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)*.
- **`discharge::EMB.UnionCapacity`**:\
  The discharge storage parameters must include a capacity.
  The discharge capacity is the capacity **after** taking into account the discharging efficiency from the viewpoint of the storage level.
  This is also shown in the section on the *[level constraints](@ref nodes-battery-math-con-add-level)*
  More information can be found on *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)*.
  !!! note "Permitted values for storage parameters in `charge`, `level`, and `discharge`"
      If the node should contain investments through the application of [`EnergyModelsInvestments`](https:// energymodelsx.github.io/EnergyModelsInvestments.jl/stable/), it is important to note that you can only use `FixedProfile` or `StrategicProfile` for the capacity, but not `RepresentativeProfile` or `OperationalProfile`.
      Similarly, you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
      The variable operating expenses can be provided as `OperationalProfile` as well.
      In addition, all capacity and fixed OPEX values have to be non-negative.
- **`stor_res::ResourceEmit`**:\
  The `stor_res` is the stored [`Resource`](@extref EnergyModelsBase.Resource).
  In the case of a battery, you must specifiy your *electricity* resource.
- **`input::Dict{<:Resource, <:Real}`** and **`output::Dict{<:Resource, <:Real}`**:\
  Both fields describe the `input` and `output` [`Resource`](@extref EnergyModelsBase.Resource)s with their corresponding conversion factors as dictionaries.
  The values correspond to charge and discharge efficiencies from the `AbstractBattery` nodes.\
  All values have to be in the range ``[0, 1]``.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.
  In the current version, it is only relevant for additional investment data when [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) is used.

### [Additional fields](@id nodes-battery-fields-new)

[`AbstractBattery`](@ref) nodes add additional fields compared to [`RefStorage`](@extref EnergyModelsBase.RefStorage) nodes.
These fields are located below the field `output` and before the field `data`.

The individual fields are related to specifics of batteries.
These fields are given as:

- **`battery_life::AbstractBatteryLife`**:\
  The battery life is incorporated to include the potential for either battery type to include battery storage degradation.
  It is explained in more detail *[above](@ref nodes-battery-phil-life)*.
- **`reserve_up::Vector{<:ResourceCarrier}`**:\
  The upwards reserve is only included for [`ReserveBattery`](@ref) nodes.
  It corresponds to the potential of the node to *deliver* reserve electricity to the system in a given operational period.\
  The specified resources cannot be part of the `input` or `output` dictionaries.
- **`reserve_down::Vector{<:ResourceCarrier}`**:\
  The downwards reserve is only included for [`ReserveBattery`](@ref) nodes.
  It corresponds to the potential of the node to *receive* reserve electricity from the system in a given operational period.\
  The specified resources cannot be part of the `input` or `output` dictionaries.

## [Mathematical description](@id nodes-battery-math)

In the following mathematical equations, we use the name for variables and functions used in the model.
Variables are in general represented as

``\texttt{var\_example}[index_1, index_2]``

with square brackets, while functions are represented as

``func\_example(index_1, index_2)``

with paranthesis.

### [Variables](@id nodes-battery-math-var)

#### [Standard variables](@id nodes-battery-math-var-stand)

The battery node types utilize all standard variables from `RefStorage`, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*.
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

#### [Additional variables](@id nodes-battery-math-add)

[`AbstractBattery`](@ref) nodes by default calculate the charging of a battery in the individual periods, even if the battery life is modelled as [`InfLife`](@ref)
Hence, the following additional variables are included through providing a new methods to [`EnergyModelsBase.variables_node()`](@ref):

- ``\texttt{bat\_prev\_use}[n, t]``: Previous charging of battery ``n`` at the beginning of operational period ``t`` with a typical unit of MWh.\
  The previous use corresponds to how much the battery is charged up to the current operational period.
  It is utilized for calculating the degradation of the battery.
- ``\texttt{bat\_prev\_use\_sp}[n, t_{inv}]``: Previous charging of battery ``n`` at the beginning of investmet period ``t_{inv}`` with a typical unit of MWh.\
  The previous use corresponds to how much the battery is charged up to the current investment period.
  It is utilized for calculating the degradation of the battery.
- ``\texttt{bat\_use\_sp}[n, t_{inv}]``: Charging of battery ``n`` in investment period ``t_{inv}`` with a typical unit of MWh.\
  The use allows to see how many charging cycles are conducted within an investment period.
  It is utilized for calculating the degradation of the battery.
- ``\texttt{bat\_use\_rp}[n, t_{rp}]``: Charging of battery ``n`` in representantive period ``t_{rp}`` with a typical unit of MWh.\
  The use allows to see how many charging cycles are conducted within a representative period.
  It is utilized for calculating the degradation of the battery.\
  It is only created if the time structure includes representative periods.
- ``\texttt{bat\_stack\_replace\_b}[n, t_{inv}]``: Binary variable representing replacement of the battery stack.\
  The battery stack replacement is occuring at the beginning of an investment period and results in setting the previous use to 0.
  Consequently, the initial capacity is available again.\
  It is only created for battery nodes with [`CycleLife`](@ref).

[`ReserveBattery`](@ref) nodes create two additional variables:

- ``\texttt{bat\_res\_up}[n, t]``: Available upwards reserve of battery ``n`` in operational period ``t`` with a typical unit of MW.\
  The upwards reserve corresponds to the potential of the battery to provide additional capacity to the system.
  The capacity is required to be sufficient for a duration of 1 of an operational period as outlined in *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS)*.
- ``\texttt{bat\_res\_down}[n, t]``: Available downwards reserve of battery ``n`` in operational period ``t`` with a typical unit of MW.\
  The downwards reserve corresponds to the potential of the battery to use surplus capacity in the system for charging the battery.
  The capacity is required to be sufficient for a duration of 1 of an operational period as outlined in *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS)*.

### [Constraints](@id nodes-battery-math-con)

The following sections omit the direct inclusion of the vector of battery storage nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`Battery`](@ref) or [`ReserveBattery`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all investment periods).

#### [Standard constraints](@id nodes-battery-math-con-stand)

Battery storages nodes utilize in general the standard constraints described on *[Constraint functions](@extref EnergyModelsBase man-con)* for `RefStorage` nodes.

These standard constraints are:

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

- `constraints_flow_in`:\
  The auxiliary resource constraints are independent of the chosen storage behavior:

  ```math
  \texttt{flow\_in}[n, t, p] = inputs(n, p) \times \texttt{flow\_in}[n, stor\_res(n)]
  \qquad \forall p \in inputs(n) \setminus \{stor\_res(n)\}
  ```

  The stored resource constraints are depending on the chosen storage behavior.
  it is given by

  ```math
  \texttt{flow\_in}[n, t, stor\_res(n)] = \texttt{stor\_charge\_use}[n, t]
  ```

- `constraints_level`:
  The level constraints are in general following the default approach with minor modifications.
  They are explained in detail below in *[Level constraints](@ref nodes-battery-math-con-add-level)*

- `constraints_opex_var`:

  ```math
  \begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\ \sum_{t \in t_{inv}}&
    opex\_var(level(n), t) \times \texttt{stor\_level}[n, t] \times scale\_op\_sp(t_{inv}, t) + \\ &
    opex\_var(charge(n), t) \times \texttt{stor\_charge\_use}[n, t] \times scale\_op\_sp(t_{inv}, t) + \\ &
    opex\_var(discharge(n), t) \times \texttt{stor\_discharge\_use}[n, t] \times scale\_op\_sp(t_{inv}, t)
  \end{aligned}
  ```

  !!! tip "The function `scale_op_sp`"
      The function [``scale\_op\_sp(t_{inv}, t)``](@extref EnergyModelsBase.scale_op_sp) calculates the scaling factor between operational and investment periods.
      It also takes into account potential operational scenarios and their probability as well as representative periods.

- `constraints_data`:\
  This function is only called for specified data of the CO₂ storage node, see above.

!!! info "Implementation of OPEX"
    The fixed and variable OPEX constribubtion for the charge, the level, and the discharge capacities are only included if the corresponding *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)* have a field `opex_fixed` and `opex_var`, respectively.
    Otherwise, they are omitted.

Batteries require a new method for `constraints_capacity`.
While the charge and discharge capacities are unaffected by the storage level degradation,

```math
\begin{aligned}
\texttt{stor\_charge\_inst}[n, t] & \geq \texttt{stor\_charge\_use}[n, t] \\
\texttt{stor\_discharge\_inst}[n, t] & \geq \texttt{stor\_discharge\_use}[n, t] \\
\end{aligned}
```

is is impacting the storage level capacity.
If the node utilizes [`InfLife`](@ref), the function reverts to the default behavior given by

```math
\texttt{stor\_level\_inst}[n, t]  \geq \texttt{stor\_level}[n, t] \\
```

However, if the node utilizes [`CycleLife`](@ref), we have to include battery degradation through

```math
\begin{aligned}
\texttt{stor\_level\_inst}[n, t] - & degradation(n) \times \texttt{bat\_prev\_use}[n, t] / cycles(n) \\ &
  \geq \texttt{stor\_level}[n, t]
\end{aligned}
```

The degradation corresponds to a linear degradation between a fresh battery with 0 cycles and a worn out battery at the maximum nubmer of cycles.
It is implemented through the function [`capacity_reduction`](@ref EnergyModelsRenewableProducers.capacity_reduction).

The outlet flow of a [`Battery`](@ref) node is similar to a [`RefStorage`](@extref EnergyModelsBase.RefStorage) node.
It is reusing the functionality of the function `constraints_flow_out` for `Storage` nodes given by

```math
\texttt{flow\_out}[n, t, stor\_res(n)] = \texttt{stor\_discharge\_use}[n, t]
```

[`ReserveBattery`](@ref) nodes include a new method to also include the outflow of the reserve resources.
This outflow does **not** correspond to a physical flow of energy or mass.
Instead, it is purely utilized for accounting purposes.

The provided reserve for the specified reserve resources ``P^{up} = reserve\_up(n)`` and ``P^{down} = reserve\_down(n)`` is given by

```math
\begin{aligned}
\texttt{bat\_res\_up}[n, t] & = \sum_{p \in P^{up}} \texttt{flow\_out}[n, t, p] \\
\texttt{bat\_res\_down}[n, t] & \sum_{p \in P^{down}} \texttt{flow\_out}[n, t, p] \\
\end{aligned}
```

The fixed operating expenditures, calculated through the function `constraints_opex_fixed`, requires a new method to include the costs for the battery stack replacement.
It first creates an auxiliary variable ``stack\_replace`` which is given as

```math
stack\_replace[t_{inv}] = stor\_level\_current[n, t_{inv}] \times bat\_stack\_replace\_b[n, t_{inv}]
```

if the battery includes investment options or

```math
stack\_replace[t_{inv}] = capacity(level(n), t_{inv}) \times bat\_stack\_replace\_b[n, t_{inv}]
```

if the battery does not include investments.
The bilinearity is reformulated using the function [`linear_reformulation`](@ref EnergyModelsRenewableProducers.linear_reformulation).
This auxiliary variable is subsequently utilized in the calculation of the

```math
\begin{aligned}
\texttt{opex\_fixed}&[n, t_{inv}] = \\ &
  opex\_fixed(level(n), t_{inv}) \times \texttt{stor\_level\_inst}[n, first(t_{inv})] + \\ &
  opex\_fixed(charge(n), t_{inv}) \times \texttt{stor\_charge\_inst}[n, first(t_{inv})] + \\ &
  opex\_fixed(discharge(n), t_{inv}) \times \texttt{stor\_discharge\_inst}[n, first(t_{inv})] + \\ &
  stack\_cost(n) \times stack\_replace[t_{inv}] / duration\_strat(t_{inv})
\end{aligned}
```

!!! tip "Why do we divide by `duration_strat(t_inv)`"
    Stack replace occurs always at the beginning of an investment period ``t_{inv}`` and only once in an investment period.
    The variable ``\texttt{opex\_fixed}[n, t_{inv}]`` is multiplied in the objective function with ``duration\_strat(t_{inv})``.
    As a consequence, if the duration of the investment period is larger than 1, we would invest multiple times into a new stack.
    Consequently, we have to divide the costs by the duration of the investment period.

!!! tip "Why do we use `first()`"
    The variables ``\texttt{stor\_level\_inst}`` are declared over all operational periods (see the section on *[Capacity variables](@extref EnergyModelsBase man-opt_var-cap)* for further explanations).
    Hence, we use the function ``first(t_{inv})`` to retrieve the installed capacities in the first operational period of a given investment period ``t_{inv}`` in the function `constraints_opex_fixed`.

#### [Additional constraints](@id nodes-battery-math-con-add)

##### [Battery use constraints](@id nodes-battery-math-con-add-use)

The calculation of the previous battery use requires the definition of new constraint functions as the approach differs depending on the chosen `TimeStructure`.
The overall approach is similar to the calculation of the level constraints in `EnergyModelsBase`.
The core function is [`constraints_usage`](@ref EnergyModelsRenewableProducers.constraints_usage) from which the individual iteration is achieved.

Within this function, we first calculate ``\forall t_{inv} \in T^{Inv}`` the use of a battery within each investment period:

```math
\begin{aligned}
\texttt{bat\_use\_sp}[n, t_{inv}] = \sum_{t \in t_{inv}} & \texttt{stor\_charge\_use}[n, t] \times \\ &
  inputs(n, p_{stor}) \times scale\_op\_sp(t_{inv}, t) \\
\end{aligned}
```

In addition, we calculate the charging of the storage up to the current investment period ``t_{inv}`` through the subfunction [`constraints_usage_sp`](@ref EnergyModelsRenewableProducers.constraints_usage_sp).
This function has two distinctive methods:

1. If the current investment period is the first, we add the following constraint:

   ```math
   \texttt{bat\_prev\_use\_sp}[n, t_{inv}] = 0
   ```

2. In all other investment periods it is given by

   ```math
   \texttt{bat\_prev\_use\_sp}[n, t_{inv}] = \texttt{disjunct}[t_{inv}]
   ```

   in which we introduce an auxiliary variable ``\texttt{disjunct}[t_{inv}]``.
   The meaning of the auxiliary variable is depending on the chosen battery life type.
   For all [`AbstractBatteryLife`](@ref EnergyModelsRenewableProducers.AbstractBatteryLife), if not specified differently, it is simply given as:

   ```math
   \begin{aligned}
   \texttt{disjunct}[t_{inv}] = & \texttt{bat\_prev\_use\_sp}[n, t_{inv, prev}] + \\ &
     \texttt{bat\_use\_sp}[n, t_{inv}] \times duration\_strat(t_{inv, prev}) \\
   \end{aligned}
   ```

   we have to include a bilinear term:

   ```math
   \begin{aligned}
   \texttt{disjunct}[t_{inv}] = & ( \texttt{bat\_prev\_use\_sp}[n, t_{inv, prev}] + \\ &
     \texttt{bat\_use\_sp}[n, t_{inv}] \times duration\_strat(t_{inv, prev}) ) \times \\ &
     \texttt{bat\_stack\_replace\_n}[n, t_{inv}] \\
   \end{aligned}
   ```

   which is reformulated within the function directly.
   The differentiation is achieved through the subfunction [`replace_disjunct`](@ref EnergyModelsRenewableProducers.replace_disjunct).

The function subsequently calls the function [`constraints_usage_iterate`](@ref EnergyModelsRenewableProducers.constraints_usage_iterate) which iterates through the time structure and adds relevant constraints.

If the `TimeStructure` includes representative periods, then the use in each representative period ``t_{rp}`` is calculated (in the function `constraints_usage_iterate`):

```math
\begin{aligned}
\texttt{bat\_use\_rp}[n, t_{rp}] = \sum_{t \in t_{rp}} & \texttt{stor\_charge\_use}[n, t] \times \\ &
  inputs(n, p_{stor}) \times scale\_op\_sp(t_{rp}, t) \\
\end{aligned}
```

Once we reach the lowest time structure, *i.e.*, `SimpleTimes`, we enforce in the case of [`CycleLife`](@ref) the upper bound on the number of cycles of the battery for the last operational period ``t`` (in the last representative period for each operational scenario, if used) of an investment period as:

```math
\begin{aligned}
cycles(n) \times & \texttt{stor\_level\_inst}[n, t] \geq \\ &
  \texttt{bat\_prev\_use}[n, t] + \texttt{bat\_use\_sp}[n, t_{inv}] \times duration\_strat(t_{inv, prev}) \\
\end{aligned}
```

The declaration of the actual constraint for the previous use utilises the helper variable ``prev\_use`` in the following constraint:

```math
\begin{aligned}
\texttt{bat\_}&\texttt{prev\_use}[n, t] = \\ &
 prev\_use[t] + \\ &
\texttt{stor\_charge\_use}[n, t] \times \\ &
  inputs(n, p_{stor}) \times duration(t) \\ &
\end{aligned}
```

The individual value of the auxiliary variable ``prev\_use`` can be differentiated in three individual cases:

1. In the first operational period (in the first representative period) in investment periods:\
   The constraint is given as

   ```math
   prev\_use[t] = \texttt{bat\_prev\_use\_sp}[n, t_{inv}]
   ```

   with ``t_{inv, pre} < t_{inv}``.
2. In the first operational period in subsequent representative periods:\
   The constraint is given as

   ```math
   \begin{aligned}
   prev\_use[t] = & \texttt{bat\_prev\_use}[n, first(t_{rp,prev})] - \\ &
     \texttt{stor\_charge\_use}[n, first(t_{rp,prev})] \times \\ &
     inputs(n, p_{stor}) \times duration(first(t_{rp,prev})) + \\ &
   \texttt{bat\_use\_rp}[n, t_{rp,prev}] \\
   \end{aligned}
   ```

   with ``t_{rp,prev}`` denoting the previous representative period.
   The subtraction is necessary as the use is calculated at the end of a period.
3. In all other operational periods

   ```math
   prev\_use[t] = \texttt{bat\_prev\_use}[n, t_{prev}]
   ```

   with ``t_{prev}`` denoting the previous operational period.

Note, that the auxiliary variable is not directly implemented.
Instead, the JuMP macro `@expression` is utilized.

##### [Reserve constraints](@id nodes-battery-math-con-add-reserve)

The reserve requires new constraints for calculating the potential of the [`ReserveBattery`](@ref) to provide reserve capacity.
This is achieved through the function [`constraints_reserve`](@ref EnergyModelsRenewableProducers.constraints_reserve) called from the `create_node` function.

A standard [`AbstractBattery`](@ref) node does not add any constraints when calling the function.
A [`ReserveBattery`](@ref) adds the following additional constraints for specifying the available upwards reserve:

```math
\begin{aligned}
\texttt{stor\_discharge\_use}[n, t] - & \texttt{stor\_charge\_use}[n, t] \leq \\ &
  \texttt{stor\_discharge\_inst}[n, t] - \texttt{bat\_res\_up}[n, t] \\
\texttt{stor\_level}[n, t] - & \texttt{bat\_res\_up}[n, t] \geq 0 \\
\end{aligned}
```

and downwards reserve:

```math
\begin{aligned}
\texttt{stor\_charge\_use}[n, t] - & \texttt{stor\_discharge\_use}[n, t] \leq \\ &
  \texttt{stor\_charge\_inst}[n, t] - \texttt{bat\_res\_down}[n, t] \\
\texttt{stor\_level}[n, t] + & \texttt{bat\_res\_down}[n, t] \leq \\ &
  \texttt{stor\_level\_inst}[n, t] - \\ &
    degradation(n) \times \texttt{bat\_prev\_use}[n, t] / cycles(n) \\
\end{aligned}
```

The second constraint is replaced by

```math
\texttt{stor\_level}[n, t] + \texttt{bat\_res\_down}[n, t] \leq \texttt{stor\_level\_inst}[n, t]
```

if the node uses [`InfLife`](@ref), and hence, does not include battery degradation.

!!! note "Required time for providing the reserve"
    As can be seens from above constraints, it is necessary to provide the reserve capacity for at least a duration of 1 of an operational period.
    If you use hourly resolution, it corresponds to an hour, even if the duration of the representative periods is longer (specified through a value differeing from 1 in the time structure).
    This concept is explained in the section *[utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS)*.

##### [Level constraints](@id nodes-battery-math-con-add-level)

The level constraints are in general slightly more complex to understand.
The overall structure is outlined on *[Constraint functions](@extref EnergyModelsBase man-con-stor_level)*.
The level constraints are called through the function `constraints_level` which then calls additional functions depending on the chosen time structure (whether it includes representative periods and/or operational scenarios) and the chosen *[storage behaviour](@extref EnergyModelsBase lib-pub-nodes-stor_behav)*.

The battery nodes utilize the majority of the concepts from `EnergyModelsBase` but require adjustments for both constraining the variable ``\texttt{stor\_level\_Δ\_op}`` and specifying how the storage node has to behave in the first operational period of an investment period.
This is achieved through dispatching on the functions `constraints_level_aux`.

The constraints introduced in `constraints_level_aux` are given by the energy balance with ``p_{stor}`` corresponding to the stored resource:

```math
\begin{aligned}
  \texttt{stor\_level\_Δ\_op}&[n, t] = \\ &
  \texttt{stor\_charge\_use}[n, t] \times inputs(n, p_{stor}) - \\ &
  \texttt{stor\_discharge\_use}[n, t] / outputs(n, p_{stor})
\end{aligned}
```

If the time structure includes representative periods, we also calculate the change of the storage level in each representative period within the function `constraints_level_iterate` (from `EnergyModelsBase`):

```math
  \texttt{stor\_level\_Δ\_rp}[n, t_{rp}] = \sum_{t \in t_{rp}}
  \texttt{stor\_level\_Δ\_op}[n, t] \times scale\_op\_sp(t_{inv}, t)
```

The general level constraint is calculated in the function `constraints_level_iterate` (from `EnergyModelsBase`):

```math
\texttt{stor\_level}[n, t] = prev\_level +
\texttt{stor\_level\_Δ\_op}[n, t] \times duration(t)
```

in which the value ``prev\_level`` is depending on the type of the previous operational (``t_{prev}``) and investment period (``t_{inv,prev}``) (as well as the previous representative period (``t_{rp,prev}``)).
It is calculated through the function `previous_level`.

In the case of battery nodes, we can distinguish the following cases:

1. The first operational period in the first representative period in any investment period (given by ``typeof(t_{prev}) = typeof(t_{rp, prev})`` and ``typeof(t_{inv,prev}) = NothingPeriod``).
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

2. The first operational period in subsequent representative periods in any investment period (given by ``typeof(t_{prev}) = nothing``) if the the storage behavior is given as [`CyclicStrategic`](@extref EnergyModelsBase.CyclicStrategic):\

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
