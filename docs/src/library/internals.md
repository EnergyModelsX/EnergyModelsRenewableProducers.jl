# Internals

## [`NonDisRES`](@ref)

## [`HydroStor`](@ref) and [`PumpedHydroStor`](@ref)

Since we also want to be able to model hydropower plant nodes *without* pumps, we include the boolean `has_pump` in the type describing hydropower. For combining the behavior of a dam with- and without a pump, we can disable the inflow of energy by setting the constraint

  ``\texttt{:flow\_in}[n, t, p_\texttt{stor}] = 0 \qquad \forall\, t \in \mathcal{T},``

for the stored resource ``p_\texttt{stor}`` `::Resource` for the node ``n`` `::HydroStor`. To acess this variable, we therefore have to let the type `HydroStorage` be a subtype of `EMB.Storage`. All fields and their type is listed in the type documentation in the [public documentation](@ref sec_lib_public_docs).

## [Optimization variables](@id sec_lib_internal_opt_vars)

The only new optimization variable added by this package, is `:curtailment[n, t]` defined for all nodes ``n`` `::NonDisRes` and all ``t\in\mathcal{T}``. This variable is created by the method [`EnergyModelsBase.variables_node`](@ref) which is a method called from `EnergyModelsBase`. The variable represents the amount of energy *not* produced by node ``n`` `::NonDisRes` at operational period ``t``.

The variable is defined by the following constraint,

  ``\texttt{:cap\_use}[n, t] + \texttt{:curtailment}[n, t] = n.\texttt{Profile}[t] \cdot \texttt{:cap\_inst}[n, t] \qquad \forall\,t\in\mathcal{T},``

for all nodes ``n`` `::NonDisRES`.

## Methods

```@autodocs
Modules = [EnergyModelsRenewableProducers]
Public = false
Order = [:type, :function]
```
