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
include("constraint_functions.jl")

# Legacy constructors for node types
include("legacy_constructor.jl")

export NonDisRES
export HydroStorage, RegHydroStor, HydroStor, PumpedHydroStor
export HydroReservoir, HydroGenerator, HydroPump, HydroGate
export EnergyEquivalent
export MinConstraint, MaxConstraint, ScheduleConstraint

end # module
