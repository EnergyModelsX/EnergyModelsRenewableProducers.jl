# [Methods - Internal](@id lib-int-met)

## [Index](@id lib-int-met-idx)

```@index
Pages = ["methods-EMRP.md"]
```

## [Constraint functions](@id lib-int-met-con)

```@docs
EMRP.build_pq_constaints
EMRP.constraints_usage
EMRP.constraints_usage_iterate
EMRP.constraints_usage_sp
EMRP.constraints_reserve
```

## [Identification functions](@id lib-int-met-ident)

```@docs
EMRP.is_constraint_data
EMRP.is_constraint_resource
EMRP.is_active
EMRP.has_penalty
EMRP.has_penalty_up
EMRP.has_penalty_down
EMRP.has_degradation
```

## [Check functions](@id lib-int-met-check)

```@docs
EMRP.check_battery_life
```

## [Utility functions](@id lib-int-met-util)

```@docs
EMRP.capacity_max
EMRP.linear_reformulation
EMRP.multiplication_variables
EMRP.previous_usage
EMRP.capacity_reduction
EMRP.replace_disjunct
```

## [Variable extraction functions](@id lib-int-met-fun_var_extract)

```@docs
EMRP.get_var_inst
EMRP.get_var_schedule
EMRP.get_var_pen_up
EMRP.get_var_pen_down
```
