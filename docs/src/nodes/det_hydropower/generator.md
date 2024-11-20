# [Hydro generator node](@id nodes-det_hydro_power-generator)

## [Introduced type and its field](@id nodes-det_hydro_power-generator-fields)

The [`HydroGenerator`](@ref) node represents a hydropower unit used to generate electricity in a hydropower system.
In its simplest form, the [`HydroGenerator`](@ref) can convert potential energy stored in the reservoirs to electricity by discharging water between reservoirs at different head levels under the assumption that the reservoirs have constant head level.
The conversion to electric energy can be described by an power-discharge relationship referred to as the PQ-curve.

### [Standard fields](@id nodes-det_hydro_power-generator-fields-stand)

[`HydroGenerator`](@ref) nodes build on the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) and the  [`RefNetworkNode` ](@extref EnergyModelsBase.RefNetworkNode) nodes, but add additional fields.
The standard fields are:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
  This is similar to the approach utilized in `EnergyModelsBase`.
- **`cap::TimeProfile`**:\
  The installed capacity corresponds to the nominal capacity of the node.
  It can refer to either the installed power or discharge capacity of the hydropower unit.
- **`opex_var::TimeProfile`**:\
  The variable operational expenses are based on the capacity utilization through the variable [`cap_use`](@extref EnergyModelsBase man-opt_var-cap).
- **`opex_fixed::TimeProfile`**:\
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of a strategic period as outlined on *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS)*.\
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.

  !!! note "Additional constraints"
      The `data` field can be used to add minimum, maximum, and schedule constraints on the power generation or water discharge using the general *[constraints types](@ref nodes-det_hydro_power-phil-con)*.

!!! warning "Input/output fields"
    [`HydroGenerator`](@ref) nodes do not utilize the fields `input` and `output`.
    Instead, the input and output resources are identified from the fields `water_resource` and `electricity_resource` described below.

### [Additional fields](@id nodes-det_hydro_power-generator-fields-add)

[`HydroGenerator`](@ref) nodes introduce the following additional fields:

- **`pq_curve::AbstractPqCurve`**:\
  Describes the *[relationship between generated power (electricity) and discharge of water](@ref nodes-det_hydro_power-phil-pq)*.
  The input can be provided by using the subtype [`PqPoints`](@ref) or as a single energy equivalent.

  !!! warning "pq_curve"
      The input provided to the `pq_curve` field has to be relative to the installed capacity, so that either the maximum discharge or the maximum power value given by the [`PqPoints`](@ref) equals 1.
      If a single energy equivalent is provided, it is required that the field `cap` must refer to the power capacity of the [`HydroGenerator`](@ref) node.

- **`water_resource::Resource`**:\
  The water resource that the node discharges to generate electricity.
- **`electricity_resource::Resource`**:\
  The electricity resource generated from the node.

!!! note "Input/output fields"
    [`HydroGenerator`](@ref) nodes include the fields `water_resource` and `electricity_resource` field instead of the `input` and `output` fields of [`RefNetworkNode`](@extref EnergyModelsBase.RefNetworkNode).
    The conversion of the water resource is set to 1 since the amount of water in the system is constant.
    The conversion to electricity is described by the input provided in the `pq_curve::AbstractPqCurve` field.

## [Mathematical description](@id nodes-det_hydro_power-generator-math)

The [`HydroGenerator`](@ref) inherits its mathematical description from the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) which is an abstract subtype of [NetworkNode](@extref EnergyModelsBase.NetworkNode).

### [Variables](@id nodes-det_hydro_power-generator-math-var)

#### [Standard variables](@id nodes-det_hydro_power-generator-math-var-stand)

The [`HydroGenerator`](@ref) utilizes the standard variables from the [NetworkNode](@extref EnergyModelsBase.NetworkNode), as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*.

- [``\texttt{opex\_var}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{cap\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{cap\_inst}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{flow\_in}``](@extref EnergyModelsBase man-opt_var-flow)
- [``\texttt{flow\_out}``](@extref EnergyModelsBase man-opt_var-flow)

#### [Additional variables](@id nodes-det_hydro_power-generator-math-add)

In addition to the standard variables, the variables presented below are defined for [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit).
These variabels are hence created for [`HydroGenerator`](@ref) nodes.

- ``\texttt{discharge\_segments}[n, t, q]``: One discharge variable is defined for each segment `q` of the PQ-curve defined by the field `pq_curve` of node ``n`` in operational period ``t`` with unit volume per time unit.\
  If [`PqPoints`](@ref) are provided, the number of discharge segments will be ``Q``, where ``Q+1`` is the length of the vectors in the fields of [`PqPoints`](@ref).
  There is only one discharge segment if an energy equivalent is used.
  The variables ``\texttt{discharge\_segments}`` define the utilisation of each discharge segment and sum up to the total discharge.

  !!! warning "discharge_segments"
      Sequential allocation is not enforced by binary variables, but allocation will occure sequentially if the problem if set up correctly.
      Penalties for spilling water, a non-concave PQ-curve or an otherwise non-convex problem are examples thay may result in a non-sequential allocation.

The following variables are created if required by the *[additional constraints](@ref nodes-det_hydro_power-phil-con)*:

- ``\texttt{gen\_penalty\_up}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction *up* in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.\
  *Up* implies in this case that the electricity generation is larger than planned.
- ``\texttt{gen\_penalty\_down}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction *down* in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.\
  *Down* implies in this case that the electricity generation is smaller than planned.

### [Constraints](@id nodes-det_hydro_power-generator-math-con)

In the following sections the vector of [`HydroGenerator`](@ref) nodes are omitted from the descriptions.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroGenerator`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods).

#### [Standard constraints](@id nodes-det_hydro_power-generator-math-con-stand)

[`HydroGenerator`](@ref) nodes utilize in general the standard constraints described in *[Constraint functions for `NetworkNode`](@extref EnergyModelsBase nodes-network_node-math-con)*.
The majority of these constraints are hence ommitted in the following description.

The function `constraints_capacity` rquires a new method to account for the included [PQ-curve](@ref nodes-det_hydro_power-phil-pq):

```math
\begin{aligned}
    \texttt{cap\_use}&[n, t] \leq \texttt{cap\_inst}[n, t] \times \frac{P^{max}}{capacity(n, t)}\\
\end{aligned}
```

Where `capacity(n, t)` is the installed capacity of node `n` in operational period `t` and ``P^{max}`` is the maximum power capacity identified through the function [`max_power`](@ref EnergyModelsRenewableProducers.max_power).

The function `constraints_opex_var` requires a new method as we have to include the penalty variables for violating the constraints if required:

```math
\begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\
    \sum_{t \in t_{inv}}  \Big( &opex\_var(n, t) \times \texttt{cap\_use}[n, t] + \\&
    \sum_{p \in P^{res}} \Big( penalty(c_{up}, t) \times \texttt{gen\_penalty\_up}[n, t, p] + \\&
    penalty(c_{down}, t) \times \texttt{gen\_penalty\_down}[n, t, p] \Big) \Big) \times scale\_op\_sp(t_{inv}, t)
\end{aligned}
```

where ``penalty()`` returns the penalty value for violation in the upward and downward direction of constraints with penalty variables, denoted by ``c_{up}`` and  ``c_{up}`` respectively.
The set ``P^{res}`` contains the water and power resources of node `n`.

!!! tip "The function `scale_op_sp`"
    The function [``scale\_op\_sp(t_{inv}, t)``](@extref EnergyModelsBase.scale_op_sp) calculates the scaling factor between operational and strategic periods.
    It also takes into account potential operational scenarios and their probability as well as representative periods.

Furthermore, we provide new methods for the flow constraints for `HydroGenerator` nodes:

- `constraints_flow_in`:\
  It is assumed that the amount of water is constant for `HydroGenerator` nodes, and the flow of water into the node therefore equals the flow out:

  ```math
  \texttt{flow\_in}[n, t, water\_resource(n)] = \texttt{flow\_out}[n, t, water\_resource(n)]
  ```

- `constraints_flow_out`:\
  The flow out of water is constrained to total discharge given by the sum of the ``\texttt{discharge\_segments[n,t,q]}`` variables, where Q is the number of segments in the PQ-curve (*i.e.*, Q+1 PQ-points):

  ```math
  \texttt{flow\_out}[n, t, water\_resource(n)] = \sum_{q=1}^{Q}\texttt{discharge\_segments[n,t,q]}
  ```

  The flow of electricity out of the node is given by the ``\texttt{cap\_use}[n, t]`` variables:

  ```math
  \texttt{flow\_out}[n, t, electricity\_resource(n)] = \texttt{cap\_use}[n, t]
  ```

  In addition to being constrained by the installed capacity, the variables ``\texttt{cap\_use}``  are constrained by the discharge of water multiplied with the conversion rate given by ``\texttt{E[q]}`` which is the slope of each segment in the PQ-curve:

  ```math
  \texttt{cap\_use}[n, t] = \sum_{q=1}^{Q}(\texttt{discharge\_segments}[n,t,q] \times \texttt{E[q]})
  ```

  The discharge segments are constrained by the `discharge_levels` of the [`PqPoints`](@ref):

  ```math
  \begin{aligned}
      \texttt{discharge\_segment}[n, t, q] \leq & capacity(n, t) \times (discharge\_levels[q+1] \\ &
      - discharge\_levels[q]) \qquad \forall q \in [1,Q] \\
  \end{aligned}
  ```

  The `capacity(n, t)` returns the installed capacity and is used to scale the relative values of the  [`PqPoints`](@ref) to absolute values.

!!! note "Energy equivalent"
    If a single energy equivalent is used, two points (zero and max) are created to describe a single discharge segment with the slope of the energy equivalent and the capacity of node `n`.
    In this case, the installed capacity of the node, provided in the `pq_curve::AbstractPqCurve` field, has to refer to the power capacity.

Furthermore, the method for `constraints_flow_out` adds *[discharge and power capacity constraints](@ref nodes-det_hydro_power-phil-con)* if additional constraints are provided in the `Data` field.
Soft constraints, *i.e.*, constraints with a penalty, are used if the constraints have non-infinite penalty values.
For `HydroGenerator` nodes, the constraints can be defined for both the `electricity_resource` and `water_resource`. The mathematical formualtion of the constraints are:

1. Minimum constraints for discharge or power generation:

   ```math
   \begin{aligned}
     \texttt{flow\_out}[n, t, p] \geq & capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{min}\\
     \texttt{flow\_out}[n, t, p] + \& \texttt{gen\_penalty\_up}[n, t, p] \geq \\ &
        capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{min} \\
   \end{aligned}
   ```

2. Maximum constraints for discharge or power generation:

   ```math
   \begin{aligned}

     \texttt{flow\_out}[n, t, p] \leq & capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{max}\\
     \texttt{flow\_out}[n, t, p] - & \texttt{gen\_penalty\_down}[n, t, p] \leq \\ &
        capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{max} \\

   \end{aligned}
   ```

3. Scheduling constraints for discharge or power generation:

   ```math
   \begin{aligned}
     \texttt{flow\_out}[n, t, p] = & capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{sch}\\
     \texttt{flow\_out}[n, t, p] + & \texttt{gen\_penalty\_up}[n, t, p] - \texttt{gen\_penalty\_down}[n, t] = \\ &
     capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{sch} \\
   \end{aligned}
   ```

where ``value(c,t)`` returns the relative limit of constraint `c` and  ``capacity(n,t, p)`` returns the installed capacity of node `n` for resource `p`.
The sets ``C^{min}``,``C^{max}``, and ``C^{sch}`` contain additional minimum, maximum and scheduling constraints, repectively.
