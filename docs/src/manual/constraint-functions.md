# [Constraint functions](@id constraint_functions)

The [`HydroStorage`](@ref) types dispatch on individual functions from within `EnergyModelsBase.jl` ti extend the functionality

## Storage level constraints

All [`HydroStorage`](@ref) subtypes utilize the same function, `constraints_level(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)`, for calling the two relevant subfunctions.

The function

```julia
EMB.constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EnergyModel)
```

is extended to account for both the provision of an initial level at the start of each strategic period as well as modifying the constraint for the variable ``\texttt{stor\_level\_}\Delta\texttt{\_op}`` to account for the introduction of the new variable ``\texttt{hydro\_spill}``.
The former is required for [`HydroStorage`](@ref) subtypes asthe initial level is frequently a function of the season (excluding small scale pumped hydro storage) while the latter is required to include spillage.

The functions

```julia
EMB.constraints_level_sp(m, n::HydroStorage, t_inv, 𝒫, modeltype::EnergyModel)
```

are similar to the function used for `RefStorage{T} where {T<:ResourceCarrier}`.
It is however necessary to reintroduce it due to the declaration for `RefStorage` in `EnergyModelsBase.jl`.
This will most likely be adjusted in later versions, although it will not impact the user directly.

## Operational expenditure constraints

Variable operational expenditure (OPEX) constraints are slightly different defined in the case of [`HydroStor`](@ref) and [`PumpedHydroStor`](@ref) nodes.
Hence, dispatch is required on the individual constraints:

```julia
EMB.constraints_opex_var(m, n::HydroStor, 𝒯::TimeStructure, modeltype::EnergyModel)
EMB.constraints_opex_var(m, n::PumpedHydroStor, 𝒯::TimeStructure, modeltype::EnergyModel)
```

Within a [`HydroStor`](@ref) node, the variable OPEX is defined *via* the outflow from the hydropower plant, contrary to the definition of a `RefStorage` node in which the variable OPEX is defined *via* the inflow.
A [`PumpedHydroStor`](@ref) has contributions by both the inflow (through the field `opex_var_pump`) and the outflow (through the field `opex_var`).
