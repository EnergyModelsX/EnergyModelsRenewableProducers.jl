# [Hydro pump node](@id nodes-det_hydro_power-pump)

## [Introduced type and its field](@id nodes-det_hydro_power-pump-fields)

The [`HydroPump`](@ref) node represents a hydropower unit that consumes electricity to pump water between two reservoir in a hydropower system.
The [`HydroPump`](@ref) can convert electricity to potential energy stored in the reservoirs by pumping water between reservoirs at different head levels under the assumption that the reservoirs has constant head level.
The conversion from electric energy is the reversed process of the energy conversion in the [`HydroGenerator`](@ref) and can be described by an power-discharge relationship, where discharge refer to the flow of pumped water.

### [Standard fields](@id nodes-det_hydro_power-pump-fields-stand)

[`HydroPump`](@ref) nodes build on the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) and the  [`RefNetworkNode` ](@extref EnergyModelsBase.RefNetworkNode) nodes, but add additional fields.
The standard fields are:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
  This is similar to the approach utilized in `EnergyModelsBase`.
- **`cap::TimeProfile`**:\
  The installed capacity corresponds to the nominal capacity of the node.
  It is the installed pumping capacity, either in form of volume water per time period or power capacity.
- **`opex_var::TimeProfile`**:\
  The variable operational expenses are based on the capacity utilization through the variable [`cap_use`](@extref EnergyModelsBase man-opt_var-cap).
- **`opex_fixed::TimeProfile`**:\
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of a strategic period as outlined on *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS)*.
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.

  !!! note "Additional constraints"
      The `data` field can be used to add minimum, maximum, and schedule constraints on pumping using the general *[constraints types](@ref nodes-det_hydro_power-phil-con)*.

!!! warning "Input/output fields"
    [`HydroGenerator`](@ref) nodes do not utilize the fields `input` and `output`.
    Instead, the input and output resources are identified from the fields `water_resource` and `electricity_resource` described below.

### [Additional fields](@id nodes-det_hydro_power-pump-fields-stand)

- **`pq_curve::AbstractPqCurve`**:\
  Describes the *[relationship between consumed power (electricity) and pumped water](@ref nodes-det_hydro_power-phil-pq)*.
  The input can be provided by using the subtype [`PqPoints`](@ref) or as a single energy equivalent.

!!! warning "pq_curve"
    The input provided to the `pq_curve` field has to be relative to the installed capacity, so that either the maximum discharge or the maximum power value given by the [`PqPoints`](@ref) equals 1.
    If a single energy equivalent is provided the `cap::TimeProfile` must refer to the power capacity of the [`HydroGenerator`](@ref) node.

- **`water_resource::Resource`**:\
  The water resource that the node pumps between reservoirs.
- **`electricity_resource::Resource`**:\
  The electricity resource consumed in the node.

!!! note "Input/output fields"
    [`HydroPump`](@ref) nodes include the fields `water_resource` and `electricity_resource` field instead of the `input` and `output` fields of [`RefNetworkNode`](@extref EnergyModelsBase.RefNetworkNode).
    The conversion of the water resource is set to 1 since the amount of water in the system is constant.
    The conversion to electricity is described by the input provided in the `pq_curve::AbstractPqCurve` field.

## [Mathematical description](@id nodes-det_hydro_power-pump-math)

The [`HydroPump`](@ref) inherits its mathematical description from the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) and [NetworkNode](@extref EnergyModelsBase.NetworkNode).

### [Variables](@id nodes-det_hydro_power-pump-math-var)

#### [Standard variables](@id nodes-det_hydro_power-pump-math-var-stand)

The [`HydroPump`](@ref) utilizes the standard variables from the [NetworkNode](@extref EnergyModelsBase.NetworkNode), as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*.

- [``\texttt{opex\_var}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{cap\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{cap\_inst}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{flow\_in}``](@extref EnergyModelsBase man-opt_var-flow)
- [``\texttt{flow\_out}``](@extref EnergyModelsBase man-opt_var-flow)

#### [Additional variables](@id nodes-det_hydro_power-pump-math-add)

In addition to the standard variables, the variables presented below are defined for [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) nodes.
These variabels are hence created for [`HydroPump`](@ref) nodes.

- ``\texttt{discharge\_segments}[n, t, q]``: One discharge variable is defined for each segment `q` of the PQ-curve defined by the field `pq_curve` of node ``n`` in operational period ``t`` with unit volume per time unit.\
  If [`PqPoints`](@ref) are provided, the number of discharge segments will be ``Q``, where ``Q+1`` is the length of the vectors in the fields of [`PqPoints`](@ref).
  There is only one discharge segment if an energy equivalent is used. The ``\texttt{discharge\_segments}`` variables define the utilisation of each discharge segment and sums up to the total discharge.

  !!! warning "discharge_segments"
      Sequential allocation is not enforced by binary variables, but will occure sequentially if the problem if set up correctly.
      A non-convex PQ-curve for the pump may result in a non-sequential allocation.

The following variables are created if required by the *[additional constraints](@ref nodes-det_hydro_power-phil-con)*:

- ``\texttt{gen\_penalty\_up}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction *up* in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.
  *Up* implies in this case that the reservoir volume is larger than planned.
- ``\texttt{gen\_penalty\_down}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction *down* in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.
  *Down* implies in this case that the reservoir volume is smaller than planned.

### [Constraints](@id nodes-det_hydro_power-pump-math-con)

The following sections omit the direct inclusion of the vector of [`HydroPump`](@ref) nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroPump`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods).

#### [Standard constraints](@id nodes-det_hydro_power-pump-math-con-stand)

[`HydroPump`](@ref) nodes utilize in general the standard constraints described in *[Constraint functions for `NetworkNode`](@extref EnergyModelsBase nodes-network_node-math-con)*.
The majority of these constraints are hence ommitted in the following description.

The new methods for the functions `constraints_capacity` and `constraints_opex_var` are explained in the *[section for `HydroGenerator`](@ref nodes-det_hydro_power-generator-math-con-stand)*.

Furthermore, we dispatche on the flow constraints for `HydroPump` nodes.
The mathematical description is the same as for the `HydroGenerator` nodes, except that electricity flows into the node (is consumed) rather than out of the node:

- `constraints_flow_in`:\
  It is assumed that the amount of water is constant for `HydroGenerator` nodes, and the flow of water into the node therefore equals the flow out.

  ```math
      \texttt{flow\_in}[n, t, water\_resource(n)] = \texttt{flow\_out}[n, t, water\_resource(n)]
  ```

  The flow of electricity into the node is given by the:

  ```math
  \texttt{flow\_in}[n, t, electricity\_resource(n)] = \texttt{cap\_use}[n, t]
  ```

- `constraints_flow_out`:\
  The flow out of water is constrained to total discharge given by the sum of the ``\texttt{discharge\_segments[n,t,q]}`` variables, where Q is the number of segments in the PQ-curve (*i.e.*, Q+1 PQ-points):

  ```math
  \texttt{flow\_out}[n, t, water\_resource(n)] = \sum_{q=1}^{Q}\texttt{discharge\_segments[n,t,q]}
  ```

  In addition to being constrained by the installed capacity, the ``\texttt{cap\_use}`` variables are constrained by the discharge of water multiplied with the conversion rate given by ``\texttt{E[q]}`` which is the slope of each segment in the PQ-curve:

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
    If a single energy eqivalent is used, two points (zero and max) are created to describe a single discharge segment with the slope of the energy equivalent and the capacity of node `n`.
    In this case, the installed capacity of the node, provided in the pq_curve::AbstractPqCurve field, has to refer to the power capacity.

Furthermore, the dispatch on `constraints_flow_in` includes additional pumping capacity constraints.
The constraints are optional and only added to the problem if given as input in the `Data` field of the nodes.
Soft constraints, *i.e.*, constraints with a penalty, are used if the constraints have non-infinite penalty values.
For [`HydroPump`](@ref) nodes, the constraints can be defined for the `electricity_resource` and `water_resource`, limiting the flow into of the node.

1. Minimum constraints for pumping:

   ```math
   \begin{aligned}
     \texttt{flow\_out}[n, t, p] \geq & capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{min}\\
     \texttt{flow\_out}[n, t, p] + \& \texttt{gen\_penalty\_up}[n, t, p] \geq \\ &
        capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{min} \\
   \end{aligned}
   ```

2. Maximum constraints for pumping:

   ```math
   \begin{aligned}

     \texttt{flow\_out}[n, t, p] \leq & capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{max}\\
     \texttt{flow\_out}[n, t, p] - & \texttt{gen\_penalty\_down}[n, t, p] \leq \\ &
        capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{max} \\

   \end{aligned}
   ```

3. Scheduling constraints for v:

   ```math
   \begin{aligned}
     \texttt{flow\_out}[n, t, p] = & capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{sch}\\
     \texttt{flow\_out}[n, t, p] + & \texttt{gen\_penalty\_up}[n, t, p] - \texttt{gen\_penalty\_down}[n, t] = \\ &
     capacity(n, t, p) \times value(c, t) \qquad & \forall c \in C^{sch} \\
   \end{aligned}
   ```

where ``value(c,t)`` returns the relative limit of constraint `c` and  ``capacity(n,t, p)`` returns the installed capacity of node `n` for resource `p`.
The sets ``C^{min}``,``C^{max}``, and ``C^{sch}`` contain additional minimum, maximum and scheduling constraints, repectively.
