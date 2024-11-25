# [Public interface](@id lib-pub)

## [Module](@id lib-pub-module)

```@docs
EnergyModelsRenewableProducers
```

## [Node types](@id lib-pub-node)

### [Abstract types](@id lib-pub-node-abstract)

```@docs
HydroStorage
AbstractNonDisRES
AbstractBattery
```

### [Concrete types](@id lib-pub-node-concrete)

```@docs
Battery
ReserveBattery
NonDisRES
HydroStor
PumpedHydroStor
HydroReservoir
HydroGenerator
HydroPump
HydroGate
```

### [Legacy constructors](@id lib-pub-node-legacy)

```@docs
RegHydroStor
```

## [Additional types](@id lib-pub-add)

### [Providing a battery lifetime](@id lib-pub-add-bat_life)

The battery nodes can have either an infinity lifetime or a finite lifetime in which the capacity is reduced due to charging the battery.
In this case, the lifetime is given by the number of cycles.

```@docs
InfLife
CycleLife
```

### [Constraint types](@id lib-int-types-con)

```@docs
MinSchedule
MaxSchedule
EqualSchedule
ScheduleConstraint
```

### [Power-flow curves](@id lib-int-types-pq)

```@docs
PqPoints
```
