# [Optimization variables](@id optimization_variables)

`EnergyModelsRenewableProduces.jl` declares new variables for the introduced `Nodes`.
The different variables are explained below including how they are introduced in different constraints.
Thes variables are created by the method [`EMB.variables_node`](@ref) which is a method dispatched on from `EnergyModelsBase.jl`.

## [`NonDisRES`](@ref)

`NonDisRES` is a subtype of the `Source` node declared in `EnergyModelsBase.jl`.
Hence, it has by default the same variables as a `RefSource` node declared in `EnergyModelsBase.jl`.

In addition, the following new optimization variable is added:

* ``\texttt{curtailment}[n, t]``: Curtailment of `NonDisRES` node ``n`` in operational period ``t``.

Curtailment represents the amount of energy *not* produced by node ``n`` `::NonDisRes` at operational period ``t``.

The variable is used in the following constraint within [`EMB.create_node(m, n::NonDisRES, 𝒯, 𝒫, modeltype::EnergyModel)`](@ref),

  ``\texttt{cap\_use}[n, t] + \texttt{curtailment}[n, t] = \texttt{profile}(n, t) \cdot \texttt{cap\_inst}[n, t]``.

!!! note
    Brackets ``[n, t]`` correspond to accessing a variable, while parenthesis ``(n, t)`` correspond to functions for accessing fields of a composite type.

## [`HydroStorage`](@ref)

Both [`PumpedHydroStor`](@ref) and [`HydroStor`](@ref) are in a fist instance subtypes of [`HydroStorage`](@ref), and hence, subtypes of the `Storage` node declared in `EnergyModelsBase.jl`.
Hence, it has by default the same variables as a `RefStorage` node declared in `EnergyModelsBase.jl`.

In addition, the following new optimization variable is added:

* ``\texttt{hydro\_spill}[n, t]``: Spillage from `HydroStorage` node ``n`` in operational period ``t``.

The spillage is introduced to allow for an overflow from a reservoir if the inflow to a reservoir exceed its capacity and the outflow through power generation.

The variable is used in the following constraint [`EMB.constraints_level_aux`](@ref),

  ``\texttt{stor\_level\_}\Delta\texttt{\_op}[n, t] = \texttt{level\_inflow}(n, t) + \texttt{inputs}(n, p_{\texttt{Power}}) \cdot \texttt{flow\_in}[n, t] + \texttt{stor\_rate\_use}[n, t] - \texttt{hydro\_spill}[n, t]``

for the stored resource ``p_{\texttt{Power}}``.

!!! note
    Brackets ``[n, t]`` correspond to accessing a variable, while parenthesis ``(n, t)`` correspond to functions for accessing fields of a composite type.
