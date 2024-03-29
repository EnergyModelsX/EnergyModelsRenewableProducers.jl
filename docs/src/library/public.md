# [Public interface](@id sec_lib_public)

## [`NonDisRES` (non-dispatchable renewable energy source)](@id NonDisRES_public)

This type models both wind power, solar power, and run of river hydropower.
These have in common that they generate power from an intermittent energy source, so they can have large variations in power output, based on the availability of the renewable source at the time.
These power sources can be modelled using the same type [`NonDisRES`](@ref).
The new type is a subtype of `EMB.Source`. The new type only differs from its supertype through the field `profile`.

The field `profile::TimeProfile` is a dimensionless ratio (between 0 and 1) describing how much of the installed capacity is utilized at the current operational period.
Therefore, when using [`NonDisRES`](@ref) to model some renewable source, the data provided to this field is what defines the intermittent characteristics of the source.

The [`NonDisRES`](@ref) node is modelled very similar to a regular `EMB.Source}` node. The only difference is how the intermittent nature of the non-dispatchable source is handled. The maximum power generation of the source in the operational period ``t`` depends on the time-dependent `Profile` variable.

!!! note
    If not needed, the production does not need to run at full capacity. The amount of energy *not* produced is computed using the non-negative [optimization variable](@ref optimization_variables) ``\texttt{curtailment}`` (declared for [`NonDisRES`](@ref) nodes only).

The fields of the different types are listed below:

```@docs
NonDisRES
```

## [`HydroStorage` (regulated hydro storage with or without pump)](@id HydroStorage_public)

A hydropower plant is much more flexible than, *e.g.*, a wind farm since the water can be stored for later use.
Energy can be produced (almost) whenever it is needed.
Some hydropower plants also have pumps installed.
These are used to pump water into the reservoir when excess and cheap energy is available in the network.

The field `rate_cap` describes the installed production capacity of the (aggregated) hydropower plant.
The variable `level_init` represents the initial energy available in the reservoir in the beginning of each investment period, while `stor_cap` is the installed storage capacity in the reservoir.
The variable `level_inflow` describes the inflow into the reservoir (measured in energy units), while `level_min` is the allowed minimum storage level in the dam, given as a ratio of the installed storage capacity of the reservoir at
every operational period.
The required minimum level is enforced by NVE and varies over the year.
The resources stored in the hydro storage is set as `stor_res`, similar to a regular `EMB.RefStorage`.

The five last parameters are used in the same way as in `EMB.Storage`.
In the implementation of [`PumpedHydroStor`](@ref), the values set in `input` represents a loss of energy when using the pumps.
A value of `1` means no energy loss, while a value of `0` represents 100% energy loss of that inflow variable.
[`PumpedHydroStor`](@ref) has in addition the field `opex_var_pump::TimeProfile`.
This field corresponds to the variable operational expenditures when pumping water into the storage reservoir.

Since we also want to be able to model hydropower plant nodes *without* pumps, we include the boolean `has_pump` in the type describing hydropower.
For combining the behavior of a hydropower plant with and without a pump, we can disable the inflow of energy by setting the constraint

  ``\texttt{flow\_in}[n, t, p_{\texttt{Power}}] = 0,``

for the stored resource ``p_{\texttt{Power}}`` for the node ``n`` `::HydroStor`.
To access this variable, we therefore have to let the type `HydroStorage` be a subtype of `EMB.Storage`.

The fields of the different types are listed below:

```@docs
HydroStorage
HydroStor
PumpedHydroStor
RegHydroStor
```
