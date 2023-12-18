# [Public interface](@id sec_lib_public)

## `NonDisRES` (non-dispatchable renewable source)

This type models both wind power, solar power, and run of river hydropower.
These have in common that they generate power from an intermittent energy source, so they can have large variations in power output, based on the availability of the renewable source at the time.
These power sources are modelled using the same type [`NonDisRES`](@ref).
The new type is a subtype of `EMB.Source`. The new type only differs from its supertype through the field `Profile`.

The field `Profile::TimeProfile` is a dimensionless ratio (between 0 and 1) describing how much of the installed capacity is utilized at the current operational period. Therefore, when using [`NonDisRES`](@ref) to model some renewable source, the data provided to this field is what defines the intermittent characteristics of the source.

The [`NonDisRES`](@ref) node is modelled very similar to a regular `EMB.Source}` node. The only difference is how the intermittent nature of the non-dispatchable source is handled. The maximum power generation of the source in the operational period ``t`` depends on the time-dependent `Profile` variable.

!!! note
    If not needed, the production does not need to run at full capacity. The amount of energy *not* produced is computed using the non-negative [optimization variable](@ref sec_lib_internal_opt_vars) `:curtailment` (declared for [`NonDisRES`](@ref) nodes only).

## `HydroStorage` (regulated hydro storage with or without pump)

A hydropower plant is much more flexible than, *e.g.*, a wind farm since the water can be stored for later use. Energy can be produced (almost) whenever it is needed.
Some hydropower plants also have pumps installed.
These are used to pump water into the reservoir when excess and cheap energy is available in the network.

The field `rate_cap` describes the installed production capacity of the
(aggregated) hydropower plant. The variable `level_init` represents the initial
energy available in the reservoir in the beginning of each investment period,
while `stor_cap` is the installed storage capacity in the reservoir. The
variable `level_inflow` describes the inflow into the reservoir (measured in
energy units), while `level_min` is the allowed minimum storage level in the
dam, given as a ratio of the installed storage capacity of the reservoir at
every operational period. The required minimum level is enforced by NVE and
varies over the year. The resources stored in the hydro storage is set as
`stor_res`, similar to a regular `EMB.RefStorage`.

The five last parameters are used in the same way as in `EMB.Storage`.
In the implementation of [`PumpedHydroStor`](@ref), the values set in `input` represents a loss of energy when using the pumps.
A value of `1` means no energy loss, while a value of `0` represents 100% energy loss of that inflow variable.
[`PumpedHydroStor`](@ref) has in addition the field `opex_var_pump::TimeProfile`.
This field corresponds to the variable operational expenditures when pumping water into the storage reservoir.

## [References](@id sec_lib_public_docs)

```@autodocs
Modules = [EnergyModelsRenewableProducers]
Private = false
Order = [:type, :function]
```
