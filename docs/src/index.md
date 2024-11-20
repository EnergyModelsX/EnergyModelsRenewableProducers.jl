# EnergyModelsRenewableProducers

This Julia package implements new nodes with corresponding JuMP variables and constraints, extending the package [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/) with more detailed representation of *renewable energy sources*.

These nodes are

1. a `Source` node [`NonDisRES`](@ref),
2. a `Storage` node ([`HydroStor`](@ref)),
3. a `Storage` node ([`PumpedHydroStor`](@ref)),
4. a `Storage` node ([`HydroReservoir`](@ref)),
5. a `NetworkNode` node ([`HydroGenerator`](@ref)),
6. a `NetworkNode` node ([`HydroPump`](@ref)), and
7. a `NetworkNode` node ([`HydroGate`](@ref)).

The new introduced node types are also documented in the *[public library](@ref lib-pub)* as well as the corresponding nodal page.

## Developed nodes

### [`NonDisRES`](@ref)

The first node models a non-dispatchable renewable energy source, like wind power, solar power, or run of river hydropower.
These all use intermittent energy sources in the production of energy, so the maximum production capacity varies with the availability of the energy source at the time.

### Simple hydropower

The [`PumpedHydroStor`](@ref) and [`HydroStor`](@ref) nodes implement a regulated hydropower storage plant, either with or without pumps for filling the reservoir with excess energy. These nodes can be used to model a single hydropower plant and reservoir, or to model an aggregated description of a hydropower system. The nodes do not include conversion from water to energy, and therby requires an energy-based descriton of the hydropower system.
The hydropower storage plant can also be extended as they are declared as subtypes of [`HydroStorage`](@ref).

### Detailed hydropower

Cascaded hydropower systems can be modelled usind the [`HydroReservoir`](@ref), [`HydroGate`](@ref), [`HydroGenerator`](@ref), and [`HydroPump`](@ref) nodes.
These nodes can be used in combination to model a detailed hydropower system.
Unlike [`HydroStorage`](@ref) nodes, these nodes allow for modelling of water as a resource that can be stored in reservoirs and moved between reservoirs to generate/consume electricity.
The [`HydroReservoir`](@ref) node is a storage node used for storing water, while [`HydroGenerator`](@ref), [`HydroPump`](@ref) and [`HydroGate`](@ref) nodes move water around in the system.
[`HydroGenerator`](@ref) and [`HydroPump`](@ref) nodes convert potential energy to electric energy and *vice versa*.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/simple-example.md",
    "manual/NEWS.md",
]
Depth = 1
```

## Description of the nodes

```@contents
Pages = [
    "nodes/nondisres.md",
    "nodes/hydropower.md",
    "nodes/det_hydropower/description.md",
    "nodes/det_hydropower/reservoir.md",
    "nodes/det_hydropower/generator.md",
    "nodes/det_hydropower/pump.md",
    "nodes/det_hydropower/gate.md",
]
Depth = 1
```

## How to guides

```@contents
Pages = [
    "how-to/contribute.md",
    "how-to/update-models.md",
]
Depth = 1
```

## Library outline

```@contents
Pages = [
    "library/public.md",
    "library/internals/types-EMRP.md",
    "library/internals/methods-fields.md",
    "library/internals/methods-EMRP.md",
    "library/internals/methods-EMB.md",
]
Depth = 1
```
