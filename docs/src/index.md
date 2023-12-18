# RenewableProducers.jl

```@docs
EnergyModelsRenewableProducers
```

This Julia package implements two nodes with corresponding JuMP constraints, extending the package 
[`EnergyModelsBase.jl`](https://clean_export.pages.sintef.no/energymodelsbase.jl/) 
with more detailed representation of *renewable energy sources*.

The first node [`NonDisRES`](@ref) models a non-dispatchable renewable energy source, like wind power, solar power, or run of river hydropower.
These all use intermittent energy sources in the production of energy, so the maximum production capacity varies with the availability of the energy source at the time.
This struct is described in detail in [Library/Public](@ref sec_lib_public).

The other node implements a regulated hydropower storage plant, both with ([`PumpedHydroStor`](@ref)) and without pumps ([`HydroStor`](@ref)) for filling the reservoir with excess energy.
These types are also documented in [Library/Public](@ref sec_lib_public).

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/philosophy.md",
    "manual/simple-example.md"
]
```

## Library outline

```@contents
Pages = ["library/public.md"]
```
