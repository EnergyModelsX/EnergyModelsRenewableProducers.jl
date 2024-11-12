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
The  [`PqPoints`](@ref) are relative to the installed capacity, so that either the maximum discharge or the maximum power value given by the [`PqPoints`](@ref) equals 1. 
This approach allows the installed capacity of the node (provided in the **`cap::TimeProfile`** fields) to refer to the electricity resource (power capacity) or the water resource (discharge/pump capacity) of the node, depending on the input used when setting up det hydropower system. 

!!! note "Energy equivalent"
    Alternatively, a single value representing the energy equivalent can be provided as input in the `pq_curve` field. By the use on a constuctor, a [`PqPoints`](@ref) struct consisting of a min and max point is then created based on the energy equvalent. If a single energy equivalent is given as input, the installed capacity (provided in the **`cap::TimeProfile`** fields) must refer to the power capacity of the [`HydroGenerator`](@ref) or [`HydroPump`](@ref) nodes.



### [Additional constraints](@id nodes-hydro-phil-con)

In addition to the constraints describing the physical system, hydropower systems are subject to a wide range of regulatory constraints or self-imposed constraints. For example to preserve ecological conditions, facilitate multiple use of water ( such as for agriculture or recreation) or ensure safe operation before/during maintanance or in the high season for recreational acitivities in the water courses. 
Often, such constraints boil down to a type of minimum, maximum or scheduling constraints. 
A general functionality has been implemented for adding such constraints to [`HydroReservoir`](@ref), [`HydroGate`](@ref), [`HydroGenerator`](@ref), and [`HydroPump`](@ref) nodes. The constraints are optional through the use of the **`data::Vector{Data}`** fields. 

- Minimum constraints [[MinConstraintType](@ref EnergyModelsRenewableProducers.MinConstraintType)]: 
- Maximum constraints [[MaxConstraintType](@ref EnergyModelsRenewableProducers.MaxConstraintType)]: 
- Schedule constraints [[ScheduleConstraintType](@ref EnergyModelsRenewableProducers.ScheduleConstraintType)]: 

### [End-value setting of water](@id nodes-hydro-phil-wv)

## [Hydro reservoir](@id nodes-hydro-res)
## [Hydro gate](@id nodes-hydro-gate)
## [Hydro generator](@id nodes-hydro-gen)
## [Hydro pump](@id nodes-hydro-pump)