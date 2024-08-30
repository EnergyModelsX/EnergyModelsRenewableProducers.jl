# EnergyModelsRenewableProducers

This Julia package implements three new nodes with corresponding JuMP variables and constraints, extending the package [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/) with more detailed representation of *renewable energy sources*.

These nodes are

1. a `Source` node [`NonDisRES`](@ref),
2. a `Storage` node ([`HydroStor`](@ref)), and
3. a `Storage` node ([`PumpedHydroStor`](@ref)).

The new introduced node types are also documented in the *[public library](@ref lib-pub)* as well as the corresponding nodal page.

## Developed nodes

### [`NonDisRES`](@ref)

The first node models a non-dispatchable renewable energy source, like wind power, solar power, or run of river hydropower.
These all use intermittent energy sources in the production of energy, so the maximum production capacity varies with the availability of the energy source at the time.

### [`HydroStor`](@ref) and [`PumpedHydroStor`](@ref)

The other nodes implement a regulated hydropower storage plant, both with ([`PumpedHydroStor`](@ref)) and without pumps ([`HydroStor`](@ref)) for filling the reservoir with excess energy.
The hydropower storage plant can also be extended as they are declared as subtypes of [`HydroStorage`](@ref).

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/simple-example.md",
    "manual/NEWS.md",
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
    "library/public.md"
    "library/internals/methods-fields.md",
    "library/internals/methods-EMB.md",
]
Depth = 1
```
