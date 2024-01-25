# RenewableProducers.jl

```@docs
EnergyModelsRenewableProducers
```

This Julia package implements two main nodes with corresponding JuMP constraints, extending the package
[`EnergyModelsBase.jl`](https://clean_export.pages.sintef.no/energymodelsbase.jl/)
with more detailed representation of *renewable energy sources*.

The first node, [`NonDisRES`](@ref), models a non-dispatchable renewable energy source, like wind power, solar power, or run of river hydropower.
These all use intermittent energy sources in the production of energy, so the maximum production capacity varies with the availability of the energy source at the time.

The other node implements a regulated hydropower storage plant, both with ([`PumpedHydroStor`](@ref)) and without pumps ([`HydroStor`](@ref)) for filling the reservoir with excess energy.
The hydropower storage plant can also be extended as they are declared as subtypes of [`HydroStorage`](@ref).

The new introduced node types are also documented in the *[public library](@ref sec_lib_public)*.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/optimization-variables.md",
    "manual/constraint-functions.md",
    "manual/simple-example.md"
]
```

## Library outline

```@contents
Pages = [
    "library/public.md"
    "library/internals.md"
    ]
```
