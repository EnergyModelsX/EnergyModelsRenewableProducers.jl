# [Methods - Internal](@id lib-int-met)

## [Index](@id lib-int-met-idx)

```@index
Pages = ["methods-EMRP.md"]
```

## [Constraint functions](@id lib-int-met-con)

```@docs
EnergyModelsRenewableProducers.build_hydro_reservoir_vol_constraints
EnergyModelsRenewableProducers.build_pq_constaints
EnergyModelsRenewableProducers.build_schedule_constraint
EnergyModelsRenewableProducers.constraints_usage
EnergyModelsRenewableProducers.constraints_usage_iterate
EnergyModelsRenewableProducers.constraints_usage_sp
EnergyModelsRenewableProducers.constraints_reserve
```

## [Identification functions](@id lib-int-met-ident)

```@docs
EnergyModelsRenewableProducers.is_constraint_data
EnergyModelsRenewableProducers.is_constraint_resource
EnergyModelsRenewableProducers.is_active
EnergyModelsRenewableProducers.has_penalty
EnergyModelsRenewableProducers.has_penalty_up
EnergyModelsRenewableProducers.has_penalty_down
EnergyModelsRenewableProducers.has_degradation
```

## [Check functions](@id lib-int-met-check)

```@docs
EnergyModelsRenewableProducers.check_battery_life
```

## [Utility functions](@id lib-int-met-util)

```@docs
EnergyModelsRenewableProducers.capacity_max
EnergyModelsRenewableProducers.linear_reformulation
EnergyModelsRenewableProducers.multiplication_variables
EnergyModelsRenewableProducers.previous_usage
EnergyModelsRenewableProducers.capacity_reduction
EnergyModelsRenewableProducers.replace_disjunct
```
