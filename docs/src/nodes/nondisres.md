# [Non-dispatchable renewable energy source node](@id nodes-nondisres)

Non-dispatchable renewable energy sources generate electricity from intermittent energy sources.
Examples for intermittent energy sources are solar irradiation, the wind, or the flow within rivers.
Although these energy sources have a constant nominal capacity, their production depends on intermittent energy sources.
Although `EnergyModelsX` allows for capacities varying on the operational level, it is then not possible to include investments for a technology.
As a consequence, the design of the [`RefSource`](@extref EnergyModelsBase.RefSource) is not satisfactory, when considering potential investments in capacities.=.

Hence, it is necessary to implement a source node representing intermittent renewable energy generation.

!!! note "Abstract supertype"
    We implemented an abstract supertype [`AbstractNonDisRES`](@ref).
    This supertype is used for introducing the variable ``\texttt{curtailment}[n, t]`` and for updating the capacity constraints.
    Hence, if you plan to create a new non-dispatchable renewable energy source, you can create it as subtype of `AbstractNonDisRES`, resulting in the variable being available.

    The function `constraints_capacity` is alsoe declared *via* this abstract supertype.

## [Introduced type and its field](@id nodes-nondisres-fields)

The [`NonDisRES`](@ref) is implemented as equivalent to a [`RefSource`](@extref EnergyModelsBase.RefSource).
Hence, it utilizes the same functions declared in `EnergyModelsBase`.

### [Standard fields](@id nodes-nondisres-fields-stand)

The standard fields are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
  This is similar to the approach utilized in `EnergyModelsBase`.
- **`cap::TimeProfile`**:\
  The installed capacity corresponds to the nominal capacity of the node.\
  If the node should contain investments through the application of [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/), it is important to note that you can only use `FixedProfile` or `StrategicProfile` for the capacity, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`opex_var::TimeProfile`**:\
  The variable operational expenses are based on the capacity utilization through the variable [`:cap_use`](@extref EnergyModelsBase man-opt_var-cap).
  Hence, it is directly related to the specified `output` ratios.
  The variable operating expenses can be provided as `OperationalProfile` as well.
- **`opex_fixed::TimeProfile`**:\
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of a strategic period as outlined on *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS)*.\
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`output::Dict{<:Resource, <:Real}`**:\
  The field `output` includes [`Resource`](@extref EnergyModelsBase.Resource)s with their corresponding conversion factors as dictionaries.
  In the case of a non-dispatchable renewable energy source, `output` should always include your *electricity* resource.In practice, you should use a value of 1.\
  All values have to be non-negative.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.
  In the current version, it is only relevant for additional investment data when [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) is used.
  !!! note
      The field `data` is not required as we include a constructor when the value is excluded.

### [Additional fields](@id nodes-nondisres-fields-new)

[`NonDisRES`](@ref) nodes add a single additional field  compared to a [`RefSource`](@extref EnergyModelsBase.RefSource):

- **`profile::TimeProfile`**:\
  The profile is used as a multiplier to the installed capacity to represent the maximum actual capacity in each operational period.
  The profile should be provided as `OperationalProfile` or at least as `RepresentativeProfile`.
  In addition, all values should be in the range ``[0, 1]``.

This field is at the 3ʳᵈ position below the field `cap` as shown in [`NonDisRES`](@ref).

## [Mathematical description](@id nodes-nondisres-math)

In the following mathematical equations, we use the name for variables and functions used in the model.
Variables are in general represented as

``\texttt{var\_example}[index_1, index_2]``

with square brackets, while functions are represented as

``func\_example(index_1, index_2)``

with paranthesis.

### [Variables](@id nodes-nondisres-math-var)

#### [Standard variables](@id nodes-nondisres-math-var-stand)

The non-dispatchable renewable energy source node types utilize all standard variables from the [`RefSource`](@extref EnergyModelsBase.RefSource) node type, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*.
The variables include:

- [``\texttt{opex\_var}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{cap\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{cap\_inst}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{flow\_out}``](@extref EnergyModelsBase man-opt_var-flow)
- [``\texttt{emissions\_node}``](@extref EnergyModelsBase man-opt_var-emissions) if `EmissionsData` is added to the field `data`.

!!! note
    Non-dispatchable renewable energy source nodes are not compatible with `CaptureData`.
    Hence, you can only provide [`EmissionsProcess`](@extref EnergyModelsBase.EmissionsProcess) to the node.
    It is our aim to include the potential for construction emissions in a latter stage

#### [Additional variables](@id nodes-nondisres-math-add)

[`NonDisRES`](@ref) nodes should keep track on the curtailment of the electricity, that is the unused capacity in each operational time period.
Hence, a single additional variable is declared through dispatching on the method [`EnergyModelsBase.variables_node()`](@ref):

- ``\texttt{curtailment}[n, t]``: Curtailed capacity of source ``n`` in operational period ``t`` with a typical unit of MW.\
  The curtailed electricity specifies the unused generation capacity of the non-dispatchable energy source.
  It is currently only used in the calculation, but not with a cost.
  This can be added by the user, if desired.

### [Constraints](@id nodes-nondisres-math-con)

The following sections omit the direct inclusion of the vector of non dispatchable renewable energy nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N^{\text{NonDisRES}\_source}`` for all [`NonDisRES`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods).

#### [Standard constraints](@id nodes-nondisres-math-con-stand)

Non-dispatchable renewable energy source nodes utilize in general the standard constraints described on *[Constraint functions](@extref EnergyModelsBase man-con)*.
In fact, they use the same `create_node` function as a [`RefSource`](@extref EnergyModelsBase.RefSource) node.
These standard constraints are:

- `constraints_capacity_installed`:

  ```math
  \texttt{cap\_inst}[n, t] = capacity(n, t)
  ```

  !!! tip "Using investments"
      The function `constraints_capacity_installed` is also used in [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) to incorporate the potential for investment.
      Nodes with investments are then no longer constrained by the parameter capacity.

- `constraints_flow_out`:

  ```math
  \texttt{flow\_out}[n, t, p] =
  outputs(n, p) \times \texttt{cap\_use}[n, t]
  \qquad \forall p \in outputs(n) \setminus \{\text{CO}_2\}
  ```

- `constraints_opex_fixed`:

  ```math
  \texttt{opex\_fixed}[n, t_{inv}] = opex\_fixed(n, t_{inv}) \times \texttt{cap\_inst}[n, first(t_{inv})]
  ```

  !!! tip "Why do we use `first()`"
      The variables ``\texttt{cap\_inst}`` are declared over all operational periods (see the section on *[Capacity variables](@extref EnergyModelsBase man-opt_var-cap)* for further explanations).
      Hence, we use the function ``first(t_{inv})`` to retrieve the installed capacities in the first operational period of a given strategic period ``t_{inv}`` in the function `constraints_opex_fixed`.

- `constraints_opex_var`:

  ```math
  \texttt{opex\_var}[n, t_{inv}] = \sum_{t \in t_{inv}} opex\_var(n, t) \times \texttt{cap\_use}[n, t] \times scale\_op\_sp(t_{inv}, t)
  ```

  !!! tip "The function `scale_op_sp`"
      The function [``scale\_op\_sp(t_{inv}, t)``](@extref EnergyModelsBase.scale_op_sp) calculates the scaling factor between operational and strategic periods.
      It also takes into account potential operational scenarios and their probability as well as representative periods.

- `constraints_data`:\
  This function is only called for specified data of the non-dispatchable renewable energy source, see above.

The function `constraints_capacity` is extended with a new method for non-dispatchable renewable energy source nodes to allow the inclusion of the production profile and the variable ``\texttt{curtailment}[n, t]``.
It now includes two individual constraints:

```math
\texttt{cap\_use}[n, t] \leq \texttt{cap\_inst}[n, t]
```

and

```math
\texttt{cap\_use}[n, t] + \texttt{curtailment}[n, t] =
profile(n, t) \times \texttt{cap\_inst}[n, t]
```

This function still calls the subfunction `constraints_capacity_installed` to limit the variable ``\texttt{cap\_inst}[n, t]`` or provide capacity investment options.

#### [Additional constraints](@id nodes-nondisres-math-con-add)

[`NonDisRES`](@ref) nodes do not add additional constraints.
