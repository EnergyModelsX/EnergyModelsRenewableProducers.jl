# [Detailed hydropower](@id nodes-storage)

Cascaded hydropower systems can be modelled usind the [`HydroReservoir`](@ref), [`HydroGate`](@ref), [`HydroGenerator`](@ref), and [`HydroPump`](@ref) nodes. The nodes can be used in combination to model a detailed hydropower system. Unlike [`HydroStorage`](@ref), these nodes allow for modelling of water as a resource that can be stored in reservoirs and moved between reservoirs to produce/consume electricity. The defined node types are:

- [`HydroReservoir`](@ref) can have water as the stored resource.
- [`HydroGenerator`](@ref) can produce electricity by moving water to a reservoir at a lower altitude or the ocean. 
- [`HydroPump`](@ref) can move water to a reservoir at a higher altitude by consuming electricity.
- [`HydroGate`](@ref) can discharge to lower reservoirs without producing electricity, for example due to spillage or environmental restrictions in the water course.

!!! warning 
    The defined node types have to be used in combination to set up a hydropower system, and should not be used as stand-alone nodes. 

## [Philosophy of the detailed hydropower nodes](@id nodes-hydro-phil)

The detailed hydropower nodes provide a flexible means to represent the physics of cascaded hydropower systems. By connecting nodes of different  types, unique systems with optional number of reservoirs, hydropower plants, pumps and discharge gates can be modelled. 

The [`HydroReservoir`](@ref) node is a storage node used for storing water, while [`HydroGenerator`](@ref), [`HydroPump`](@ref) and [`HydroGate`](@ref) nodes move water around in the system. 
In addition, [`HydroGenerator`](@ref) and [`HydroPump`](@ref) nodes convert potential energy to electric energy and wise versa. 

The detailed modelling of hydropower requires two resources to be defined: a water resource and an electricity resource.  [`HydroReservoir`](@ref) and [`HydroGate`](@ref) nodes only use the water resource, while [`HydroGenerator`](@ref) and [`HydroPump`](@ref) nodes use both resources.

The nodes should be connected by [`links`](@extref lib-pub-links) to represent the water ways in the system. Links are also used to define flow of electricity in and out of the system through [`HydroPump`](@ref) and [`HydroGenerator`](@ref) nodes, respectively. 

!!! warning "Direct linking required"
    The nodes should be connected directly and not through an availability node. Availability nodes can be used to connect electricity resources, but should not include water resources. 

!!! note "Ocean node"
    The water transported through the hydropower system requires a final destination. The ocean, or similar final destination, should be represented as a [`RefSink`](@extref EnergyModelsBase.RefSink). 

Some of the node types has similar functionality and use some of the same code. The following, describes some general functionality before a more detailed description of the nodes are provided.


### [Conversion to/from electric energy: the power-discharge relationship](@id nodes-hydro-phil-pq)

The conversion between energy stored in the water resources in the hydropower system and electric energy is described by a power-discharge relationship. 
The conversion process in the [`HydroGenerator`](@ref) and [`HydroPump`](@ref) nodes are reversed processes and modelled using the same implementation. 

The conversion is based on a set of PQ-points that describes the relationship between electric energy (power) and discharge of water, namely how much electric energy that is generated per volume of water discharged per time period. For a [`HydroPump`](@ref) node, the PQ-points describes how much electric energy the pump consumes per unit of water that is pumped to a higher reservoir, or how much water that is pumped per unit of electric energy consumed.
The PQ-points are provided as input through the `pq_curve` field of the  [`HydroGenerator`](@ref) and [`HydroPump`](@ref) nodes. 

!!! note "Relative `PqPoints`"
     The  [`PqPoints`](@ref) are relative to the installed capacity. This approach makes if possible to freely chose the capacity of the node (provided in the `cap::TimeProfile` field) to refer to the electricity resource (power capacity) or the water resource (discharge/pump capacity) of the node, depending on the input used when setting up det hydropower system. 

!!! note "Energy equivalent"
    Alternatively, a single value representing the energy equivalent can be provided as input in the `pq_curve` field. By the use on a constuctor, a [`PqPoints`](@ref) struct consisting of a min and max point is then created based on the energy equvalent. If a single energy equivalent is given as input, the installed capacity (provided in the `cap::TimeProfile` field) must refer to the power capacity of the [`HydroGenerator`](@ref) or [`HydroPump`](@ref) nodes.



### [Additional constraints](@id nodes-hydro-phil-con)

In addition to the constraints describing the physical system, hydropower systems are subject to a wide range of regulatory constraints or self-imposed constraints. For example to preserve ecological conditions, facilitate multiple use of water ( such as for agriculture or recreation) or ensure safe operation before/during maintanance or in the high season for recreational acitivities in the water courses. 
Often, such constraints boil down to a type of minimum, maximum or scheduling constraints. 
A general functionality has been implemented for adding such constraints to [`HydroReservoir`](@ref), [`HydroGate`](@ref), [`HydroGenerator`](@ref), and [`HydroPump`](@ref) nodes. The constraints are optional through the use of the **`data::Vector{Data}`** fields.

- Minimum constraints [[MinConstraintType](@ref EnergyModelsRenewableProducers.MinConstraintType)]: hard constraints (absolute) or soft constraints (with a penalty for violation) that restricts the minimum of a variable to a given value (e.g., discharge, power, reservoir level)
- Maximum constraints [[MaxConstraintType](@ref EnergyModelsRenewableProducers.MaxConstraintType)]: hard constraints (absolute) or soft constraints (with a penalty for violation) that restricts the maximum of a variable to a given value (e.g., discharge, power, reservoir level)
- Schedule constraints [[ScheduleConstraintType](@ref EnergyModelsRenewableProducers.ScheduleConstraintType)]: hard constraints (absolute) or soft constraints (with a penalty for violation) that restricts a variable to a given value (e.g., discharge, power, reservoir level)

The min, max and schedule consttaints are subtypes of the abstract type [Constraint{T<:AbstractConstraintType}](@ref EnergyModelsRenewableProducers.Constraint), where new constraints types can be implemeted as subtypes. 

### [End-value setting of water](@id nodes-hydro-phil-wv)

# [Hydro reservoir node](@id nodes-hydro_reservoir)

### [Introduced type and its field](@id nodes-hydro_reservoir-fields)
The [`HydroReservoir`](@ref) nodes represents a water storage in a hydropower system. In its simplest form, the [`HydroGenerator`](@ref) and [`HydroPump`](@ref) can convert energy between [`HydroReservoir`](@ref) nodes at different head levels to electricity, under the assumption that the reservoirs has constant head level. In these cases, the [`HydroReservoir`](@ref) does not require a description of the relation between volume level and head level. For more detailed modelling, this relation is required to account for the increased power output when the head level difference between reservoirs increase. Head-dependencies are currently not implemented.


!!! warning "Spillage"
    The [`HydroReservoir`](@ref) nodes do not include a spillage variable. To avoid infeasible solutions all reservoir nodes should be connected to a [`HydroGate`](@ref) node representing a water way for spillage in case of full reservoirs. 

#### [Standard fields](@id nodes-hydro_reservoir-fields-stand)
The [`HydroReservoir`](@ref) nodes builds on the [`RefStorage`](@extref EnergyModelsBase.RefStorage) node type. Standard fields are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
- **`vol::EMB.UnionCapacity`**:\
  The installed volume corresponds to the total water volume storage capacity of the reservoir.
- **`stor_res::ResourceCarrier`**:\
  The resource that is stored in the reservoir. Should be the reserource representing water and must be consistent for all components in the watercourse.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model. 

!!! note "additional constraints"
    The `data` field can be used to add minimum, maximum and schedule constraints for the volume using the general constraints types described [here](@ref nodes-hydro-phil-con).

    
#### [Additional fields](@id nodes-hydro_reservoir-fields-new)

[`HydroReservoir`](@ref) nodes add a single additional field compared to a [`RefStorage`](@extref EnergyModelsBase.RefStorage), and does not include the `charge` field since charge/discharge capacity is given throug the [`HydroGenerator`](@ref), [`HydroPump`](@ref), and [`HydroGate`](@ref):

- **`vol_inflow::TimeProfile`**: \
  The volume inflow to the reservoir per timestep.

### [Mathematical description](@id nodes-hydro_reservoir-math)

The mathematical description is similar to the [`RefStorage`](@extref EnergyModelsBase.RefStorage) except that the inflow is added to the storage balance.

#### [Variables](@id nodes-hydro_reservoir-math-var)

##### [Standard variables](@id nodes-hydro_reservoir-math-var-stand)
The hydro power node types utilize all standard variables from `RefStorage`, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*.

- [``\texttt{opex\_var}``](@ref man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@ref man-opt_var-opex)
- [``\texttt{stor\_level}``](@ref man-opt_var-cap)
- [``\texttt{stor\_level\_inst}``](@ref man-opt_var-cap) if the `Storage` has the field `charge` with a capacity
- [``\texttt{stor\_charge\_use}``](@ref man-opt_var-cap)
- [``\texttt{stor\_charge\_inst}``](@ref man-opt_var-cap)
- [``\texttt{stor\_discharge\_inst}``](@ref man-opt_var-cap) if the `Storage` has the field `discharge` with a capacity
- [``\texttt{stor\_discharge\_use}``](@ref man-opt_var-cap)
- [``\texttt{flow\_in}``](@ref man-opt_var-flow)
- [``\texttt{flow\_out}``](@ref man-opt_var-flow)
- [``\texttt{stor\_level\_Δ\_op}``](@ref man-opt_var-cap)
- [``\texttt{stor\_level\_Δ\_rp}``](@ref man-opt_var-cap) if the `TimeStruct` includes `RepresentativePeriods`
- [``\texttt{emissions\_node}``](@ref man-opt_var-emissions) if specified through the function [`has_emissions`](@ref) or if you use a `RefStorage{AccumulatingEmissions}`.

##### [Additional variables](@id nodes-hydro_reservoir-math-add)
- ``\texttt{rsv\_vol\_penalty\_up}[n, t]``: Variable for penalizing violation of the [volume constraint](@ref nodes-hydro-phil-con) in direction up in `HydroReservoir` node ``n`` in operational period ``t`` with a typical unit of ``Mm^3``.
- ``\texttt{rsv\_vol\_penalty\_down}[n, t]``: Variable for penalizing violation of the [volume constraint](@ref nodes-hydro-phil-con) in direction down in `HydroReservoir` node ``n`` in operational period ``t`` with a typical unit of ``Mm^3``.

The ``\texttt{rsv\_vol\_penalty\_up}[n, t]`` and ``\texttt{rsv\_vol\_penalty\_down}[n, t]`` variables are only added if required in a constraint.

#### [Constraints](@id nodes-hydro_reservoir-math-con)
The following sections omit the direct inclusion of the vector of `HydroReservoir` nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroGate`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods). 

##### [Standard constraints](@id nodes-hydro_reservoir-math-con-stand)
`HydroReservoir` nodes utilize in general the standard constraints described in *[Constraint functions for `Storage` nodes](@extref EnergyModelsBase nodes-storage-math-con)*. In addition, adjustments are required for constraining the variables ``\texttt{opex\_var}[n, t_{inv}]``, ``\texttt{stor\_level\_Δ\_op}`` and ``\texttt{stor\_level}``. This is achieved through dispatching on the functions `constraints_opex_var` and `constraints_level_aux`.

- The dispatch on `constraints_opex_var` includes the penalty variables for violating certaint constraints when required:

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

Where ``penalty()`` returnes the penalty value for violation of constraints with penalty variables in the upward and downward direction, denoted by ``c_{up}`` and  ``c_{up}``. ``scale\_op\_sp(t_{inv}, t)`` is a scaling factor. 

- The dispatch on `constraints_level_aux` alters the energy balance to include hydro inflow,

```math
\begin{aligned}
    \texttt{stor\_level\_Δ\_op}&[n, t] = \\ &
    \texttt{vol\_inflow}(n, t) + \texttt{stor\_charge\_use}[n, t] - \texttt{stor\_discharge\_use}[n, t]
\end{aligned}
```

- The dispatch on `constraints_level_aux` adds reservoir level constraints of the form described [here](@ref nodes-hydro-phil-con) if additional constraints are provided in the `Data` field. Soft constraints, i.e., constraints with a penalty, are used if the constraints have non-infinite penalty values. The mathematical formualtion of the constraints are:

1. Minumum constraints for the reservoir level:

   ```math
   \begin{aligned}
       \texttt{stor\_level}&[n, t] \geq capacity(level(n), t) \times value(c, t) \qquad \forall c \in C^{min} \\ 
       \texttt{stor\_level}&[n, t] + \texttt{rsv\_vol\_penalty\_up}[n, t] \geq \\&
       capacity(level(n), t) * value(c, t) \qquad \qquad \quad \forall c \in C^{min}
   \end{aligned}
   ```

2. Maximum constraints for the reservoir level  
   
   ```math
   \begin{aligned}
     \texttt{stor\_level}&[n, t] \leq capacity(level(n), t) \times value(c, t) \qquad \forall c \in C^{max} \\ 
     \texttt{stor\_level}&[n, t] - \texttt{rsv\_vol\_penalty\_down}[n, t] \leq \\&
     capacity(level(n), t) \times value(c, t) \qquad \qquad  \quad  \forall c \in C^{max} 
   \end{aligned}
   ```

3. Scheduling constraints for the reservoir level 

   ```math
   \begin{aligned}
     \texttt{stor\_level}&[n, t] = capacity(level(n), t) \times value(c, t) \qquad  \qquad  \qquad  \qquad  \qquad  \qquad \forall c \in C^{sch} \\
     \texttt{stor\_level}&[n, t] + \texttt{rsv\_vol\_penalty\_up}[n, t] \\
     - &\texttt{rsv\_vol\_penalty\_down}[n, t] = capacity(level(n), t) \times value(c, t) \quad  \forall c \in C^{sch} \\ 
   \end{aligned}
   ```

where ``value(c,t)`` returns the relative limit of constraint `c` and  ``capacity(n,t)`` returnes the installed capacity of node `n`. The sets ``C^{min}``,``C^{max}`` and ``C^{sch}`` contain additional minimum, maximum and scheduling constraints, repectively. 

##### [Additional constraints](@id nodes-hydro_reservoir-math-con-add)
The `HydroReservoir` nodes do not include any additional constraints other than through discpatching on *[Constraint functions for `Storage` nodes](@extref EnergyModelsBase nodes-storage-math-con)* as described above. . 


# [Hydro gate node](@id nodes-hydro_gate)

### [Introduced type and its field](@id nodes-hydro_gate-fields)
The [`HydroGate`](@ref) is used when water can be released between reservoirs without going through a generator. The [`HydroGate`](@ref) can either represent a controlled gate that is used to regulate the dispatch from a reservoir without production, or to bypass water when a reservoir is, for example, full. The [`HydroGate`](@ref) can also be used to represent spillage. Althoug spillage is not, in reality, a control decisions but a consequence of full reservoir, it is often modelled as a controllable decisions since state dependent spillage can not be modelled directly in a linear model. Costs for operating gates can be added to penalize unwanted spillage using the ``opex_var`` field.

#### [Standard fields](@id nodes-hydro_gate-fields-stand)
The [`HydroGate`](@ref) nodes builds on the [NetworkNode](@extref EnergyModelsBase.NetworkNode) node type. Standard fields are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
- **`cap::TimeProfile`**: \
  The installed gate discharge capacity.
- **`opex_var::TimeProfile`**: \
  The variable operational expenses are based on the capacity utilization through the variable [`:cap_use`](@extref EnergyModelsBase man-opt_var-cap).
- **`opex_fixed::TimeProfile`**:\
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of a strategic period as outlined on *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS)*.\
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model. 

!!! note "additional constraints"
    The `data` field can be used to add minimum, maximum and schedule constraints on the discharge using the general constraints types described [here](@ref nodes-hydro-phil-con).

#### [Additional fields](@id nodes-hydro_gate-fields-new)
- **`resource::Resource`**: \
  The water resource that the node can release.

!!! note "input/output fields"
    [`HydroGate`](@ref) includes a `resource::Resource` field instead of the `Input` and `Output` fields as a a hydro gate can only have one resource type, water, and the scaling is always 1 since water does not arise or disappear.



### [Mathematical description](@id nodes-hydro_gate-math)
The [`HydroGate`](@ref) inherits its mathematical description from the [NetworkNode](@extref EnergyModelsBase.NetworkNode) where there is only a single input and output resource given by the `resource` field and scaling 1.

#### [Variables](@id nodes-hydro_gate-math-var)

##### [Standard variables](@id nodes-hydro_gate-math-var-stand)
The [`HydroGate`](@ref) utilizes the standard variables from the `NetworkNode`, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*.
The variables that are used in the additional constraints are:

##### [Additional variables](@id nodes-hydro_gate-math-add)
- ``\texttt{gate\_penalty\_up}[n, t]``: Variable for penalizing violation of the discharge constraint in direction up in `HydroGate` node ``n`` in operational period ``t`` with unit volume per time unit.
- ``\texttt{gate\_penalty\_down}[n, t]``: Variable for penalizing violation of the discharge constraint in direction down in `HydroGate` node ``n`` in operational period ``t`` with unit volume per time unit.

 The ``\texttt{gate\_penalty\_up}[n, t]`` and ``\texttt{gate\_penalty\_down}[n, t]`` variables are only added if required in a constraint.

#### [Constraints](@id nodes-hydro_gate-math-con)
The following sections omit the direct inclusion of the vector of `HydroGate` nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroGate`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods).

##### [Standard constraints](@id nodes-hydro_gate-math-con-stand)
`HydroGate` nodes utilize in general the standard constraints described in *[Constraint functions for `NetworkNode`](@extref EnergyModelsBase nodes-network_node-math-con)*. In addition, adjustments are required for constraining the variables ``\texttt{opex\_var}`` and ``\texttt{flow\_out}``. Thisis achieved through discpatching on `constraints_opex_var` and `constraints_flow_out`.

-  The dispatch on `constraints_opex_var` includes the penalty variables for violating certain constraints when required:

```math
\begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\
    \sum_{t \in t_{inv}} \Big( &opex\_var(n, t) \times \texttt{cap\_use}[n, t] + \\&
    penalty(c_{up}, t) \times \texttt{gate\_penalty\_up}[n, t] + \\&
    penalty(c_{down}, t) \times \texttt{gate\_penalty\_down}[n, t] \Big) \times scale\_op\_sp(t_{inv}, t)
\end{aligned}
```

where ``penalty()`` returnes the penalty value for violation in the upward and downward direction of constraints with penalty variables, denoted by ``c_{up}`` and  ``c_{up}`` respectively. ``scale\_op\_sp(t_{inv}, t)`` is a scaling factor. 

- The dispatch on `constraints_flow_out` adds discharge constraints of the form described [here](@ref nodes-hydro-phil-con) if additional constraints are provided in the `Data` field. Soft constraints, i.e., constraints with a penalty, are used if the constraints have non-infinite penalty values. The mathematical formualtion of the constraints are:

1. Minimum constraints for the discharge:

   ```math
   \begin{aligned}
     \texttt{flow\_out}&[n, t, p] \geq capacity(n, t) \times value(c, t) \qquad \forall c \in C^{min}\\
     \texttt{flow\_out}&[n, t, p] + \texttt{gate\_penalty\_up}[n, t] \geq \\ &
      capacity(n, t) \times value(c, t) \qquad \qquad \quad  \forall c \in C^{min}
   \end{aligned}
   ```

2. Maximum constraints for the discharge:

   ```math
   \begin{aligned}
     \texttt{flow\_out}&[n, t, p] \leq capacity(n, t) \times value(c, t) \qquad \forall c \in C^{max}\\
     \texttt{flow\_out}&[n, t, p] - \texttt{gate\_penalty\_down}[n, t] \leq \\ &
      capacity(n, t) \times value(c, t)  \qquad \qquad \quad   \forall c \in C^{max}
   \end{aligned}
   ```

3. Scheduling constraints for the discharge:

   ```math
   \begin{aligned}
     \texttt{flow\_out}&[n, t, p] = capacity(n, t) \times value(c, t) \qquad  \qquad  \qquad  \qquad  \qquad  \qquad \forall c \in C^{sch}\\
     \texttt{flow\_out}&[n, t, p] + \texttt{gate\_penalty\_up}[n, t] \\
      -& \texttt{gate\_penalty\_down}[n, t] =  capacity(n, t) \times value(c, t) \quad  \forall c \in C^{sch}
   \end{aligned}
   ```

where ``value(c,t)`` returns the relative limit of constraint `c` and  ``capacity(n,t)`` returnes the installed capacity of node `n`. The sets ``C^{min}``,``C^{max}`` and ``C^{sch}`` contain additional minimum, maximum and scheduling constraints, repectively. 

##### [Additional constraints](@id nodes-hydro_reservoir-math-con-add)
The `HydroGate` nodes do not include any additional constraints other than through discpatching on *[Constraint functions for `NetworkNode` nodes](@extref EnergyModelsBase nodes-storage-math-con)* as described above. 


# [Hydro generator node](@id nodes-hydro_generator)

### [Introduced type and its field](@id nodes-hydro_generator-fields)
The [`HydroGenerator`](@ref) node represents a hydropower unit used to generate electricity in a hydropower system. In its simplest form, the [`HydroGenerator`](@ref) can convert potential energy stored in the reservoirs to electricity by discharging water between reservoirs at different head levels under the assumption that the reservoirs has constant head level. The conversion to electric energy can be described by an power-discharge realtionship referred to as the PQ-curve.

#### [Standard fields](@id nodes-hydro_generator-fields-stand)      
[`HydroGenerator`](@ref) nodes builds on the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) and the  [`RefNetworkNode` ](@extref EnergyModelsBase.RefNetworkNode) nodes, but add additional fields. The standard fields are:

- **`id`**: \
  The field `id` is only used for providing a name to the node.
- **`cap::TimeProfile`**: \
  Can refer to either the installed power or discharge capactiy of the hydropower unit. 
- **`opex_var::TimeProfile`**: \
  The variable operational expenses are based on the capacity utilization through the variable [`:cap_use`](@ref man-opt_var-cap).
- **`opex_fixed::TimeProfile`**: \
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of a strategic period as outlined on *[Utilize `TimeStruct`](@ref how_to-utilize_TS)*.\
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`data::Vector{Data}`**: \
  An entry for providing additional data to the model. 

!!! note "Additional constraints"
    The `data` field can be used to add minimum, maximum and schedule constraints on discharge and power using the general constraints types described [here](@ref nodes-hydro-phil-con).

#### [Additional fields](@id nodes-hydro_generator-fields-add)      

The following gives the additional fields of the [`HydroGenerator`](@ref) nodes:

- **`pq_curve::AbstractPqCurve`**: \
  Describes the [relationship between generated power (electricity) and discharge of water](@ref nodes-hydro-phil-pq). Input can be provided by using the subtype [`PqPoints`](@ref) or as a single energy equivalent. 
- **`water_resource::Resource`**: \
  The water resource that the node discharge to generate electricity.
- **`electricity_resource::Resource`**: \
  The electricity resource generated from the node.

!!! warning "pq_curve"
    The input provided to the `pq_curve` field has to be relative to the installed capacity, so that either the maximum discharge or the maximum power value given by the [`PqPoints`](@ref) equals 1. If a single energy equivalent is provided the `cap::TimeProfile` must refer to the power capacity of the [`HydroGenerator`](@ref) node.

!!! note "Input/output fields"
    [`HydroGenerator`](@ref) includes a `water_resource::Resource` and `electricity_resource::Resource` field instead of the `Input` and `Output` fields of [`RefNetworkNode`](@extref EnergyModelsBase.RefNetworkNode). The conversion of the water resource is set to 1 since the amount of water in the system is constant. The conversion to electricity is described by the input provided in the `pq_curve::AbstractPqCurve` field.


### [Mathematical description](@id nodes-hydro_generator-math)

The [`HydroGenerator`](@ref) inherits its mathematical description from the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) which is an abstract subtype of [NetworkNode](@extref EnergyModelsBase.NetworkNode).  There is a single input resource given by the `water_resource` field, and two output resources given by the `water_resource` and `electricity_resource` fields. The conversion value for the `water_resource` is set to 1, while the conversion to the `electricity_resource` is constrained by the input provided in the `pq_curve` field.

#### [Variables](@id nodes-hydro_generator-math-var)

##### [Standard variables](@id nodes-hydro_generator-math-var-stand)

The [`HydroGenerator`](@ref) utilizes the standard variables from the `NetworkNode`, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*. 

- [``\texttt{opex\_var}``](@ref man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@ref man-opt_var-opex)
- [``\texttt{cap\_use}``](@ref man-opt_var-cap)
- [``\texttt{cap\_inst}``](@ref man-opt_var-cap)
- [``\texttt{flow\_in}``](@ref man-opt_var-flow)
- [``\texttt{flow\_out}``](@ref man-opt_var-flow)
- [``\texttt{emissions\_node}``](@ref man-opt_var-emissions) if `EmissionsData` is added to the field `data`

##### [Additional variables](@id nodes-hydro_generator-math-add)

In addition to the standard variables, the variables presented below are defined for [`HydroUnit`](@ref) and created for both [`HydroGenerator`](@ref) and [`HydroPump`](@ref) nodes.
- ``\texttt{discharge\_segments}[n, t, q]``: One discharge variable is defined for each segment `q` of the PQ-curve defined by the  `pq_curve` field of node ``n`` in operational period ``t`` with unit volume per time unit. 

If [`PqPoints`](@ref) are provided, the number of discharge segments will be Q, where Q+1 is the length of the vectors in the fields of [`PqPoints`](@ref). There is only one discharge segment if an energy equivalent is used. The ``\texttt{discharge\_segments}`` variables define the utilisation of each discharge segment and sums up to the total discharge. 

!!! warning "discharge_segments"
    Sequential allocation is not enforced by binary variables, but allocation will occure sequentially if the problem if set up correctly. Penalties for spilling water, a non-concave PQ-curve or an otherwise non-convex problem are examples thay may result in a non-sequential allocation. 

The following variables are created if penalties of violating maximum discharge or power generation constraints are provided:
- ``\texttt{gen\_penalty\_up}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction up in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.
- ``\texttt{gen\_penalty\_down}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction down in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.

#### [Constraints](@id nodes-hydro_generator-math-con)
In the following sections the vector of `HydroGenerator` nodes are omitted from the descriptions.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroGenerator`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods). 

##### [Standard constraints](@id nodes-hydro_generator-math-con-stand)

The `HydroGenerator` nodes utilize the majority of the concepts from `EnergyModelsBase`. Some adjustments are required in the constraints to restrict the variables ``\texttt{opex\_var}``, ``\texttt{cap\_use}``,  ``\texttt{flow\_in}`` and ``\texttt{flow\_out}``. 

This is achieved through dispatching on the following standard constraints for `HydroUnit` nodes (used for both `HydroGenerator` and `HydroPump` nodes):

- the capacity constraint `constraints_capacity`,

```math
\begin{aligned}
    \texttt{cap\_use}&[n, t] \leq \texttt{cap\_inst}[n, t] \times \frac{P^{max}}{capacity(n, t)}\\
\end{aligned}
```
Where `capacity(n, t)` is the installed capacity of node `n` in operational period `t` and ``P^{max}`` is the maximum power capacity.

- `constraints_opex_var`

```math
\begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\
    \sum_{t \in t_{inv}}  \Big( &opex\_var(n, t) \times \texttt{cap\_use}[n, t] + \\&
    \sum_{p \in P^{res}} \Big( penalty(c_{up}, t) \times \texttt{gen\_penalty\_up}[n, t, p] + \\&
    penalty(c_{down}, t) \times \texttt{gen\_penalty\_down}[n, t, p] \Big) \Big) \times scale\_op\_sp(t_{inv}, t)
\end{aligned}
```

The dispatch of the `constraints_opex_var` constraints allows penalty variables for violating maximum and minimum discharge/power constraints to be included when required, where ``penalty()`` returnes the penalty value for violation in the upward and downward direction of constraints with penalty variables, denoted by ``c_{up}`` and  ``c_{up}`` respectively. Set ``P^{res}`` contains the water and power resources of node `n` and ``scale\_op\_sp(t_{inv}, t)`` is a scaling factor. 

Furthermore, we dispatche on the flow constraints for `HydroGenerator` nodes:

- flow into the node `constraints_flow_in`,

```math
\begin{aligned}
    \texttt{flow\_in}&[n, t, water\_resource] = \texttt{flow\_out}[n, t, water\_resource] \\ 
\end{aligned}
```

-  flow out of the node `constraints_flow_out`,

```math
\begin{aligned}
    \texttt{flow\_out}&[n, t, water\_resource] = \sum_{q=1}^{Q}\texttt{discharge\_segments[n,t,q]} \\  
    \texttt{flow\_out}&[n, t, electricity\_resource] = \texttt{cap\_use}[n, t] \\ 
    \texttt{cap\_use}&[n, t] = \sum_{q=1}^{Q}(\texttt{discharge\_segments}[n,t,q] \times \texttt{E[q]})\  
\end{aligned}
```

```math
\begin{aligned}
    \texttt{discharge\_segment}[n, t, q] \leq &capacity(n, t) \times (discharge\_levels[q+1] \\
    - &discharge\_levels[q]) \qquad \qquad  \forall q \in [1,Q] \\  
\end{aligned}
```

It is assumed that the amount of water is constant for `HydroGenerator` nodes, and the flow of water into the node therefore equals the flow out. The flow out of water is constrained to total discharge given by the sum of the ``\texttt{discharge\_segments[n,t,q]}`` variables, where Q is the number of segments in the PQ-curve (i.e., Q+1 PQ-points). The flow of electricity out of the node is given by the ``\texttt{cap\_use}[n, t]`` variables. In addition to being constrained by the installed capacity, the ``\texttt{cap\_use}`` variables are constrained by the discharge of water multiplied with the conversion rate given by ``\texttt{E[q]}`` which is the slope of each segment in the PQ-curve. 

The discharge segments are constrained by the ``\texttt{discharge\_levels}`` provided in the **`discharge_levels::Vector{Real}`** field of the [`PqPoints`](@ref). The `capacity(n, t)` returns the installed capacity and is used to scale the realtive values of the  [`PqPoints`](@ref) to absolute values. 

!!! note "Energy equivalent"
    If a single energy equivalent is used, two points (zero and max) are created to describe a single discharge segment with the slope of the energy equivalent and the capacity of node `n`. In this case, the installed capacity of the node, provided in the `pq_curve::AbstractPqCurve` field, has to refer to the power capacity. 

    
- Furthermore, the dispatch on `constraints_flow_out` adds discharge and power capacity constraints of the form described [here](@ref nodes-hydro-phil-con) if additional constraints are provided in the `Data` field. Soft constraints, i.e., constraints with a penalty, are used if the constraints have non-infinite penalty values. For `HydroGenerator` nodes, the constraints can be defined for both the `electricity_resource` and `water_resource`. The mathematical formualtion of the constraints are:


1. Minimum constraints for discharge or power generation:

   ```math
   \begin{aligned}
     \texttt{flow\_out}&[n, t, p] \geq capacity(n, t, p) \times value(c, t) \qquad \forall c \in C^{min}\\
     \texttt{flow\_out}&[n, t, p] + \texttt{gen\_penalty\_up}[n, t, p] \geq \\ &
        capacity(n, t, p) \times value(c, t) \qquad \qquad  \quad  \forall c \in C^{min}\\
   \end{aligned}
   ```
2. Maximum constraints for discharge or power generation:

   ```math
   \begin{aligned}

     \texttt{flow\_out}&[n, t, p] \leq capacity(n, t, p) \times value(c, t) \qquad \forall c \in C^{max}\\
     \texttt{flow\_out}&[n, t, p] - \texttt{gen\_penalty\_down}[n, t, p] \leq \\ &
        capacity(n, t, p) \times value(c, t)  \qquad \qquad \quad \forall c \in C^{max}\\

   \end{aligned}
   ```
3. Scheduling constraints for discharge or power generation:

   ```math
   \begin{aligned}
     \texttt{flow\_out}&[n, t, p] = capacity(n, t, p) \times value(c, t) \qquad  \qquad  \qquad  \qquad    \qquad \forall c \in C^{sch}\\
     \texttt{flow\_out}&[n, t, p] + \texttt{gen\_penalty\_up}[n, t, p] \\
     -& \texttt{gen\_penalty\_down}[n, t] = capacity(n, t, p) \times value(c, t) \qquad \qquad  \forall c \in C^{sch}\\
   \end{aligned}
   ```

where ``value(c,t)`` returns the relative limit of constraint `c` and  ``capacity(n,t, p)`` returnes the installed capacity of node `n` for resource `p`. The sets ``C^{min}``,``C^{max}`` and ``C^{sch}`` contain additional minimum, maximum and scheduling constraints, repectively. 


# [Hydro pump node](@id nodes-hydro_pump)

### [Introduced type and its field](@id nodes-hydro_pump-fields)
The [`HydroPump`](@ref) node represents a hydropower unit that consumes electricity to pump water between two reservoir in a hydropower system. The [`HydroPump`](@ref) can convert electricity to potential energy stored in the reservoirs by pumping water between reservoirs at different head levels under the assumption that the reservoirs has constant head level. The conversion from electric energy is the reversed process of the energy conversion in the [`HydroGenerator`](@ref) and can be described by an power-discharge realtionship, where discharge refer to the flow of pumped water. 


#### [Standard fields](@id nodes-hydro_pump-fields-stand)
[`HydroPump`](@ref) nodes builds on the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) and the  [`RefNetworkNode` ](@extref EnergyModelsBase.RefNetworkNode) nodes, but add additional fields. The following gives the fields of the [`HydroPump`](@ref) node and describes the differences from standard fields. See [`RefNetworkNode`](@extref EnergyModelsBase.RefNetworkNode) for information about the standard fields.

- **`id`**:\
  The field `id` is only used for providing a name to the node.
- **`cap::TimeProfile`**:\
  Refer to the installed pumping capacity, either in form of volume water per time period or power capacity. 
- **`opex_var::TimeProfile`**:\
  The variable operational expenses are based on the capacity utilization through the variable [`:cap_use`](@ref man-opt_var-cap).
- **`opex_fixed::TimeProfile`**:\
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of a strategic period as outlined on *[Utilize `TimeStruct`](@ref how_to-utilize_TS)*.\
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model. 

!!! note "Additional constraints"
    The `data` field can be used to add minimum, maximum and schedule constraints on pumping using the general constraints types described [here](@ref nodes-hydro-phil-con).

#### [Additional fields](@id nodes-hydro_pump-fields-stand)

- **`pq_curve::AbstractPqCurve`**:\ 
  Describes the [relationship between consumed power (electricity) and pumped water](@ref nodes-hydro-phil-pq). 
- **`water_resource::Resource`**:\
  The water resource that the node pumps between reservoirs.
- **`electricity_resource::Resource`**:\
  The electricity resource consumed in the node.

!!! warning "pq_curve"
    The input provided to the `pq_curve` field has to be relative to the installed capacity, so that either the maximum discharge or the maximum power value given by the [`PqPoints`](@ref) equals 1. If a single energy equivalent is provided the `cap::TimeProfile` must refer to the power capacity of the [`HydroGenerator`](@ref) node.


!!! note "Input/output fields"
    [`HydroPump`](@ref) includes a `water_resource::Resource` and `electricity_resource::Resource` field instead of the `Input` and `Output` fields of [`RefNetworkNode`](@extref EnergyModelsBase.RefNetworkNode). The conversion of the water resource is set to 1 since the amount of water in the system is constant. The conversion of the electricity sources is described by the input provided in the `pq_curve::AbstractPqCurve` field.


### [Mathematical description](@id nodes-hydro_pump-math)
The [`HydroPump`](@ref) inherits its mathematical description from the [`HydroUnit`](@ref EnergyModelsRenewableProducers.HydroUnit) and [NetworkNode](@extref EnergyModelsBase.NetworkNode). There are two input resources given by the `water_resource` and `electricity_resource` fields, and a single output resources given by the `water_resource` field. The conversion value for the `water_resource` is set to 1, while the conversion to the `electricity_resource` is constrained by the input provided in the `pq_curve` field.

#### [Variables](@id nodes-hydro_pump-math-var)

##### [Standard variables](@id nodes-hydro_pump-math-var-stand)
The [`HydroPump`](@ref) utilizes the standard variables from the `NetworkNode`, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*. The standars variables are:


- [``\texttt{opex\_var}``](@ref man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@ref man-opt_var-opex)
- [``\texttt{cap\_use}``](@ref man-opt_var-cap)
- [``\texttt{cap\_inst}``](@ref man-opt_var-cap)
- [``\texttt{flow\_in}``](@ref man-opt_var-flow)
- [``\texttt{flow\_out}``](@ref man-opt_var-flow)
- [``\texttt{emissions\_node}``](@ref man-opt_var-emissions) if `EmissionsData` is added to the field `data`


##### [Additional variables](@id nodes-hydro_pump-math-add)

In addition to the standard variables, the variables presented below are defined for [`HydroUnit`](@ref) nodes. These variabels are created for both [`HydroGenerator`](@ref) and [`HydroPump`](@ref) nodes.

- ``\texttt{discharge\_segments}[n, t, q]``: One discharge variable is defined for each segment `q` of the PQ-curve defined by the  `pq_curve` field in `HydroPump` node ``n`` in operational period ``t`` with unit volume per time unit. 

If [`PqPoints`](@ref) are provided, the number of discharge segments will be Q, where Q+1 is the length of the vectors in the fields of [`PqPoints`](@ref). There is only one discharge segment if an energy equivalent is used. The ``\texttt{discharge\_segments}`` variables define the utilisation of each discharge segment and sums up to the total discharge.   

!!! warning "discharge_segments"
    Sequential allocation is not enforced by binary variables, but will occure sequentially if the problem if set up correctly. A non-conconvex PQ-curve for the pump may result in a non-sequential allocation. 

The following variables are created if penalties of violating maximum discharge or power consumption constraints of the pump are provided:
- ``\texttt{gen\_penalty\_up}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction up in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.
- ``\texttt{gen\_penalty\_down}[n, t, p]``: Variable for penalizing violation of the maximum constraint of the resource `p` in direction down in `HydroGenerator` node ``n`` in operational period ``t`` with unit volume per time unit.

#### [Constraints](@id nodes-hydro_pump-math-con)

In the following sections the vector of `HydroPump` nodes are omitted from the descriptions.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`HydroPump`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods). 

##### [Standard constraints](@id nodes-hydro_pump-math-con-stand)


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
    \texttt{discharge\_segment}&[n, t, q] \leq capacity(n, t) \times (discharge\_levels[q+1] \\
    -& discharge\_levels[q]) \qquad  \forall q \in [1,Q] \\  
\end{aligned}
```

The mathematical description is the same as for the `HydroGenerator` nodes, except that electricity flows into the node (is consumed) rather than out of the node. It is assumed that the amount of water is constant for `HydroPump` nodes, and the flow of water into the node therefore equals the flow out. The flow out of water is constrained to total discharge given by the sum of the ``\texttt{discharge\_segments[n,t,q]}`` variables, where Q is the number of segments in the PQ-curve (i.e., Q+1 PQ-points). The flow of electricity into the node is given by the ``\texttt{cap\_use}[n, t]`` variables. In addition to being constrained by the installed capacity, the ``\texttt{cap\_use}`` variables are constrained by the discharge of water multiplied with the conversion rate given by ``\texttt{E[q]}`` which is the slope of each segment in the PQ-curve. 

The discharge segments are constrained by the ``\texttt{discharge\_levels}`` provided in the **`discharge_levels::Vector{Real}`** field of the [`PqPoints`](@ref). The `capacity(n, t)` refer to the installed capacity and scale the realtive PQ-points to absolute values. 

!!! note "Energy equivalent"
    If a single energy eqivalent is used, two points (zero and max) are created to describe a single discharge segment with the slope of the energy equivalent and the capacity of node `n`. In this case, the installed capacity of the node, provided in the pq_curve::AbstractPqCurve field, has to refer to the power capacity.


- Furthermore, the dispatch on `constraints_flow_in` includes additional pumping capacity constraints. The constraints are optional and only added to the problem if given as input in the `Data` field of the nodes. Soft constraints, i.e., constraints with a penalty, are used if the constraints have non-infinite penalty values. For `HydroPump`(@ref) nodes, the constraints can be defined for the `electricity_resource` and `water_resource`, limiting the flow into of the node.   

1. Minimum constraints for discharge or power generation:

   ```math
   \begin{aligned}
     \texttt{flow\_in}&[n, t, p] \geq capacity(n, t, p) \times value(c, t) \qquad \forall c \in C^{min} \\
         \texttt{flow\_in}&[n, t, p] + \texttt{gen\_penalty\_up}[n, t, p] \geq \\ &
        capacity(n, t, p) \times value(c, t) \qquad  \qquad  \qquad \forall c \in C^{min}
   \end{aligned}
   ```

2. Maximum constraints for discharge or power generation:

   ```math
   \begin{aligned}
     \texttt{flow\_in}&[n, t, p] \leq capacity(n, t, p) \times value(c, t) \qquad \forall c \in C^{max} \\
         \texttt{flow\_in}&[n, t, p] - \texttt{gen\_penalty\_down}[n, t, p] \leq \\ &
        capacity(n, t, p) \times value(c, t) \qquad \qquad \qquad \forall c \in C^{max} \\
   \end{aligned}
   ```

3. Scheduling constraints for discharge or power generation:

   ```math
   \begin{aligned}
     \texttt{flow\_in}&[n, t, p] = capacity(n, t, p) \times value(c, t) \qquad  \qquad  \qquad  \qquad    \qquad \forall c \in C^{sch}\\ 
         \texttt{flow\_in}&[n, t, p] + \texttt{gen\_penalty\_up}[n, t, p] \\
          -& \texttt{gen\_penalty\_down}[n, t] = 
        capacity(n, t, p) \times value(c, t) \qquad \forall c \in C^{sch}
   \end{aligned}
   ```

where ``value(c,t)`` returns the relative limit of constraint `c` and  ``capacity(n,t, p)`` returnes the installed capacity of node `n` for resource `p`. The sets ``C^{min}``,``C^{max}`` and ``C^{sch}`` contain additional minimum, maximum and scheduling constraints, repectively. 
