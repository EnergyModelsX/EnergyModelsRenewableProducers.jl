# [Hydro reservoir node](@id nodes-hydro_pump)

The [`HydroReservoir`](@ref), [`HydroGate`](@ref), [`HydroGenerator`](@ref), and [`HydroPump`](@ref) should be used for detailed hydropower modeling.
Unlike [`HydroStorage`](@ref), [`HydroReservoir`](@ref) can have water as the stored resource.
[`HydroGenerator`](@ref) can produce electricity by moving water to a lower reservoir or the ocean that should be represented as a [`RefSink`](@extref EnergyModelsBase.RefSink).
Likewise, [`HydroPump`](@ref) can consume electricity by moving water to a higher reservoir.
[`HydroGate`](@ref) can discharge to lower reservoirs without producing electricity, for example due to spillage or environmental restrictions in the water course.

## [Introduced type and its field](@id nodes-hydro_pump-fields)
The [`HydroPump`](@ref) node represents a hydropower unit that consumes electricity to pump water between two reservoir in a hydropower system.  The [`HydroPump`](@ref) can convert electricity to potential energy stored in the reservoirs by pumping water between reservoirs at different head levels under the assumption that the reservoirs has constant head level. The conversion from electric energy is the reversed process of the energy conversion in the [`HydroGenerator`](@ref) and can be described by an power-discharge realtionship, where discharge refer to the flow of pumped water. 


### [Fields](@id nodes-hydro_pump-fields-stand)
[`HydroPump`](@ref) nodes builds on the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) and the  [`RefNetworkNode` ](@extref EnergyModelsBase.RefNetworkNode) nodes, but add additional fields. The following gives the fields of the [`HydroPump`](@ref) node and describes the differences from standard fields. See [`RefNetworkNode`](@extref EnergyModelsBase.RefNetworkNode) for information about the standard fields.

- **`id`**\
- **`cap::TimeProfile`**: Can refer to either the installed power apacity or the capacity to pump water. 
- **`pq_curve::AbstractPqCurve`**: Describes the relationship between consumed power (electricity) and pumped water. 
- **`opex_var::TimeProfile`**\
- **`opex_fixed::TimeProfile`**\
- **`water_resource::Resource`**: The water resource that the node discharge to generate electricity.
- **`electricity_resource::Resource`**: The electricity resource generated from the node.
- **`data::Vector{Data}`**: An entry for providing additional data to the model. 

The **`pq_curve::AbstractPqCurve`** takes the same input as for [`HydroGenerator`](@ref) nodes, but describes a reversed process from a HydroGenerator. See more detailed description under [HydroGenerator fields](@ref nodes-hydro_generator-fields-stand).

**`data::Vector{Data}`** could be used to add minimum, maximum and schedule constraints for the pumping of water using [Constraint{T<:AbstractConstraintType}](@ref EnergyModelsRenewableProducers.Constraint), where [AbstractConstraintType](@ref EnergyModelsRenewableProducers.AbstractConstraintType) has subtypes [MinConstraintType](@ref EnergyModelsRenewableProducers.MinConstraintType), [MaxConstraintType](@ref EnergyModelsRenewableProducers.MaxConstraintType), and [ScheduleConstraintType](@ref EnergyModelsRenewableProducers.ScheduleConstraintType). The constraints values are relative to the gate capacity.

The **`output::Dict{<:Resource, <:Real}`** and **`input::Dict{<:Resource, <:Real}`** fields of the [`RefNetworkNode`](@extref EnergyModelsBase.RefNetworkNode) nodes are set internally and not used to decribe the conversion between energy sources in the [`HydroPump`](@ref) nodes. Instead the **`pq_curve::AbstractPqCurve`** is used to describe the conversion in combination with the  **`water_resource::Resource`** and  **`electricity_resource::Resource`** fields.


## [Mathematical description](@id nodes-hydro_pump-math)
The [`HydroPump`](@ref) inherits its mathematical description from the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) and [NetworkNode](@extref EnergyModelsBase.NetworkNode). There are two input resources given by the `water_resource` and `electricity_resource` fields, and a single output resources given by the `water_resource` field. The conversion value for the `water_resource` is set to 1, while the conversion to the `electricity_resource` is constrained by the input provided in the `pq_curve` field.

### [Variables](@id nodes-hydro_pump-math-var)

#### [Standard variables](@id nodes-hydro_pump-math-var-stand)
The [`HydroPump`](@ref) utilizes the standard variables from the `NetworkNode`, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*. 

#### [Additional variables](@id nodes-hydro_pump-math-add)

In addition to the standard variables, the variables presented below are defined for [`HydroUnit`](@ref) nodes. These variabels are created for both [`HydroGenerator`](@ref) and [`HydroPump`](@ref) nodes.
- ``\texttt{discharge\_segments}[n, t, q]``: One discharge variable is defined for each segment `q` of the PQ-curve defined by the  `pq_curve` field in `HydroPump` node ``n`` in operational period ``t`` with unit volume per time unit. 

If [`PqPoints`](@ref) are provided, the number of discharge segments will be Q, where Q+1 is the length of the vectors in the fields of [`PqPoints`](@ref). There is only one discharge segment if an [EnergyEquivalent](@ref EnergyModelsRenewableProducers.EnergyEquivalent) is used. The ``\texttt{discharge\_segments}`` variables define the utilisation of each discharge segment and sums up to the total discharge. Sequential allocation is not enforced by binary variables, but will occure sequentially if the problem if set up correctly. NB: a non-conconvex PQ-curve for the pump may result in a non-sequential allocation.   

The following variables are created if penalties of violating maximum discharge or power consumption constraints of the pump are provided:
- ``\texttt{gen\_penalty\_up}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction up in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.
- ``\texttt{gen\_penalty\_down}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction down in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.

### [Constraints](@id nodes-hydro_pump-math-con)

In the following sections the vector of `HydroPump` nodes are omitted from the descriptions.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroPump`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods). 

#### [Standard constraints](@id nodes-hydro_pump-math-con-stand)


The `HydroPump` nodes utilize the majority of the concepts from `EnergyModelsBase`. Some adjustments are required in the constraints to restrict the variables ``\texttt{opex\_var}``, ``\texttt{cap\_use}``, ``\texttt{flow\_in}`` and ``\texttt{flow\_out}``. 

This is achieved through dispatching on the following standard constraints for `HydroUnit` nodes (used for both `HydroGenerator` and `HydroPump` nodes) as described further [here](@ref nodes-hydro_generator-math-con-stand):

- the capacity constraint `constraints_capacity`
- `constraints_opex_var`


Furthermore, we dispatche on the flow constraints for `HydroPump` nodes:

- flow into the node `constraints_flow_in`,

```math
\begin{aligned}
    \texttt{flow\_in}&[n, t, water\_resource] = \texttt{flow\_out}[n, t, water\_resource] \\ 
    \texttt{flow\_in}&[n, t, electricity\_resource] = \texttt{cap\_use}[n, t] \\ 
\end{aligned}
```

-  flow out of the node `constraints_flow_out`,

```math
\begin{aligned}
    \texttt{flow\_out}&[n, t, water\_resource] = \sum_{q=1}^{Q}\texttt{discharge\_segments[n,t,q]} \\  
    \texttt{cap\_use}&[n, t] = \sum_{q=1}^{Q}(\texttt{discharge\_segments}[n,t,q] \times \texttt{E[q]})\\
\end{aligned}
```

```math
\begin{aligned}
    \texttt{discharge\_segment}&[n, t, q] \leq capacity(n, t) \times (discharge\_levels[q+1] - discharge\_levels[q]) \qquad  \forall q \in [1,Q] \\  
\end{aligned}
```

The mathematical description is the same as for the `HydroGenerator` nodes, except that electricity flows into the node (is consumed) rather than out of the node. It is assumed that the amount of water is constant for `HydroPump` nodes, and the flow of water into the node therefore equals the flow out. The flow out of water is constrained to total discharge given by the sum of the ``\texttt{discharge\_segments[n,t,q]}`` variables, where Q is the number of segments in the PQ-curve (i.e., Q+1 PQ-points). The flow of electricity into the node is given by the ``\texttt{cap\_use}[n, t]`` variables. In addition to being constrained by the installed capacity, the ``\texttt{cap\_use}`` variables are constrained by the discharge of water multiplied with the conversion rate given by ``\texttt{E[q]}`` which is the slope of each segment in the PQ-curve. 

The discharge segments are constrained by the ``\texttt{discharge\_levels}`` provided in the **`discharge_levels::Vector{Real}`** field of the [`PqPoints`](@ref). The `capacity(n, t)` refer to the installed capacity and is included to scale the input back to the absolute values. If an [EnergyEquivalent](@ref EnergyModelsRenewableProducers.EnergyEquivalent) is used, two points (zero and max) are created to describe a single discharge segment with the slope of the energy equivalent and the capacity of node `n`.

 The  [`PqPoints`](@ref) are defined so that either the maximum discharge or the maximum power value given by the [`PqPoints`](@ref) equals 1. This approach makes if possible to freely chose the capacity of the node (provided in the **`cap::TimeProfile`** field) to represent the power capacity or the discharge capacity of the node when setting up det hydropower system. NB: If an energy equivalent is provided as input to the **`pq_curve::AbstractPqCurve`** field, the capacity of the node has to refer to the discharge capacity. 





#### [Additional constraints](@id nodes-hydro_pump-math-con-add)

The discharge or power capacity can be restricted by adding additional minimum og maximum constraints. This is included in the dispatch of the  `constraints_flow_in` and `constraints_flow_out` constaints for `HydroUnit` nodes, and can thereby be added to both `HydroGenerator` and `HydroPump` nodes. The constraints are optional and only added to the problem if given as input in the `Data` field of the nodes. The constraints are described further in the [HydroGenerator constraints](@ref nodes-hydro_generator-math-con-add) section.


##### [Constraints calculated in `create_node`](@id nodes-hydro_pump-math-con-add-node)

##### [Level constraints](@id nodes-hydro_pump-math-con-add-level)
