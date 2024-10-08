"""
Main module for `EnergyModelsRenewableProducers.jl`.

This module implements the following types (Nodes) with constraints:
- `NonDisRes` is a subtype of `Source` and represents a \
non-dispatchable renewable producer, as wind, solar etc.
- `PumpedHydroStor` is a subtype of `Storage` and represents a regulated pumped \
hydro storage.
- `HydroStor` is a subtype of `Storage` and represents a regulated hydro storage, \
that is a standard hydro powerplant without pumps.
"""
module EnergyModelsRenewableProducers

using EnergyModelsBase
using JuMP
using TimeStruct

const EMB = EnergyModelsBase
const TS = TimeStruct

include("datastructures.jl")
include("added_datastruct.jl")
include("model.jl")
include("checks.jl")
include("constraint_functions.jl")

# Legacy constructors for node types
include("legacy_constructor.jl")

export NonDisRES
export HydroStorage, RegHydroStor, HydroStor, PumpedHydroStor
export HydroReservoir, HydroGenerator, HydroGate
export MinConstraint, MaxConstraint, ScheduleConstraint

end # module
