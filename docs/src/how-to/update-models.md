# [Update your model to the latest versions](@id update-models)

`EnergyModelsRenewableProducers` is still in a pre-release version.
Hence, there are frequently breaking changes occuring, although we plan to keep backwards compatibility.
This document is designed to provide users with information regarding how they have to adjust their models to keep compatibility to the latest changes.
We will as well implement information regarding the adjustment of extension packages, although this is more difficult due to the vast majority of potential changes.

## Adjustments from 0.4.2

### Key changes for nodal descriptions

Version 0.7 of `EnergyModelsBase` introduced both *storage behaviours* resulting in a rework of the individual approach for calculating the level balance as well as the potential to have charge and discharge capacities through *storage parameters*.

!!! note
    The legacy constructors for calls of the composite type of version 0.5 will be included at least until version 0.7.

### [`HydroStor`](@ref)

`HydroStor` was significantly reworked due to the changes in `EnergyModelsBase`
The total rework is provided below.

```julia
# The previous nodal description for a `HydroStor` node was given by:
HydroStor(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,

    level_init::TimeProfile,
    level_inflow::TimeProfile,
    level_min::TimeProfile,

    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input::Dict{<:Resource, <:Real},
    output::Dict{<:Resource, <:Real},
    data::Vector{Data},
)

# This translates to the following new version
HydroStor{CyclicStrategic}(
    id,
    StorCapOpexFixed(stor_cap, opex_fixed),
    StorCapOpexVar(rate_cap, opex_var),
    level_init,
    level_inflow,
    level_min,
    stor_res,
    input,
    output,
    data,
)
```

### [`PumpedHydroStor`](@ref)

`PumpedHydroStor` was significantly reworked due to the changers in `EnergyModelsBase`
The total rework is provided below.

```julia
# The previous nodal description for a `PumpedHydroStor` node was given by:
PumpedHydroStor(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,

    level_init::TimeProfile,
    level_inflow::TimeProfile,
    level_min::TimeProfile,

    opex_var::TimeProfile,
    opex_var_pump::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input::Dict{<:Resource, <:Real},
    output::Dict{<:Resource, <:Real},
    data::Vector{Data},
)

# This translates to the following new version
PumpedHydroStor{CyclicStrategic}(
    id,
    StorCapOpexVar(rate_cap, opex_var_pump),
    StorCapOpexFixed(stor_cap, opex_fixed),
    StorCapOpexVar(rate_cap, opex_var),
    level_init,
    level_inflow,
    level_min,
    stor_res,
    input,
    output,
    data,
)
```

## Adjustments from 0.4.0 to 0.6.x

### Key changes for nodal descriptions

Version 0.4.1 introduced two new types that replaced the original `RegHydroStor` node with two types called [`PumpedHydroStor`](@ref) and [`HydroStor`](@ref).
The changes allowed for the introduction of a variable OPEX for pumping.
In the translation below, it is assumed that the variable OPEX for pumping is 0.

```julia
# The previous nodal description was given by:
RegHydroStor(
    id::Any,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,
    has_pump::Bool,
    level_init::TimeProfile,
    level_inflow::TimeProfile,
    level_min::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input,
    output,
    Data,
)

# This translates to the following new version if has_pump == true
PumpedHydroStor(
    id,
    StorCapOpexVar(rate_cap, FixedProfile(0)),
    StorCapOpexFixed(stor_cap, opex_fixed),
    StorCapOpexVar(rate_cap, opex_var),
    level_init,
    level_inflow,
    level_min,
    stor_res,
    input,
    output,
    Data,
)
# and the following version if has_pump == false
HydroStor(
    id,
    StorCapOpexFixed(stor_cap, opex_fixed),
    StorCapOpexVar(rate_cap, opex_var),
    level_init,
    level_inflow,
    level_min,
    stor_res,
    input,
    output,
    Data,
)
```
