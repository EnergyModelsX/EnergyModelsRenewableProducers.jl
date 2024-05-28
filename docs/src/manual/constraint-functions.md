# [Constraint functions](@id constraint_functions)

## `NonDisRES` (non-dispatchable renewable energy source)

The introduction of the type [`NonDisRES`](@ref NonDisRES_public) does not require a new `create_node` function.
Instead, it is sufficient to dispatch on the function

```julia
EMB.constraints_capacity(m, n::NonDisRES, 𝒯::TimeStructure, modeltype::EnergyModel)
```

to introduce the new energy balance using the field `profile` and the variable ``\texttt{curtailment}``.
In this case, we also have to call the function

```julia
constraints_capacity_installed(m, n, 𝒯, modeltype)
```

to allow for investments when coupled with `EnergyModelsInvestments`.
We do however not need to create new methods for said function.

## `HydroStorage` (regulated hydro storage with or without pump)

The [`HydroStorage`](@ref HydroStorage_public) types utilize the same `create_node` function for introducing new concepts.
In addition, they dispatch on individual functions from within `EnergyModelsBase` to extend the functionality.

The functions

```julia
EMB.constraints_flow_in(m, n::HydroStor, 𝒯::TimeStructure, modeltype::EnergyModel)
EMB.constraints_flow_in(m, n::PumpedHydroStor, 𝒯::TimeStructure, modeltype::EnergyModel)
```

allow for a different behavior of the `HydroStorage` node through fixing the variable ``\texttt{flow\\_in}`` in the case of a [`HydroStor`](@ref) node to 0 and limiting it in the case of a [`PumpedHydroStor`](@ref) to installed charge capacity through the variable ``\texttt{stor\\_charge\\_use}``.

All `HydroStorage` subtypes utilize the introduced level balances from `EnergyModelsBase`.
MOdification to the level balance is achieved through overloading

```julia
EMB.constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EnergyModel)
```

to account for both the provision of an initial level at the start of each strategic period as well as modifying the constraint for the variable ``\texttt{stor\_level\_}\Delta\texttt{\_op}`` to account for the introduction of the new variable ``\texttt{hydro\_spill}``.
The former is required for [`HydroStorage`](@ref) subtypes as the initial level is frequently a function of the season (excluding small scale pumped hydro storage) while the latter is required to include spillage.
