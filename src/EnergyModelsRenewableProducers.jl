"""
Main module for `EnergyModelsRenewableProducers.jl`.

This module implements the following types (Nodes) with constraints:
- `NonDisRes` is a subtype of `Source` and represents a \
non-dispatchable renewable producer, as wind, solar etc.
- `PumpedHydroStor` is a subtype of `Storage` and represents a regulated pumped \
hydro storage.
- `HydroStor` is a subtype of `Storage` and represents a regulated hydro storage, \
that is a standard hydro powerplant without pumps.
- `HydroReservoir` is a subtype of `Storage` and represents a hydro storage for \
cascaded hydro power systems.
- `HydroGenerator` is a subtype of `Network` and represents a hydro generator for \
cascaded hydro power systems.
- `HydroPump` is a subtype of `Network` and represents a hydro pump for \
cascaded hydro power systems.
- `HydroGate` is a subtype of `Network` and represents a gate for cascaded hydro power \
systems.
"""
module EnergyModelsRenewableProducers

using EnergyModelsBase
using JuMP
using TimeStruct

const EMB = EnergyModelsBase
const TS = TimeStruct

include("datastructures.jl")
include("model.jl")
include("checks.jl")
include("utils.jl")
include("constraint_functions.jl")

# Legacy constructors for node types
include("legacy_constructor.jl")

# Non-dispatchable renewable energy sources types
export AbstractNonDisRES, NonDisRES

# Simple hydro power types
export HydroStorage, RegHydroStor, HydroStor, PumpedHydroStor

# Detailed hydro power types
export HydroReservoir, HydroGenerator, HydroPump, HydroGate
export PqPoints
export ScheduleConstraint, MinSchedule, MaxSchedule, EqualSchedule

# Battery types
export AbstractBattery, Battery, ReserveBattery
export InfLife, CycleLife

end # module
