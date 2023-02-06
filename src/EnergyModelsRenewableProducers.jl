"""
Main module for `EnergyModelsRenewableProducers.jl`.

This module implements two types (Nodes) with constraints.
- `NonDisRES <: Source` represents a non-dispatchable renewable producer, as wind, solar etc.
- `RegHydroStor <: Storage` represents a regulated hydro storage.
"""
module EnergyModelsRenewableProducers

using EnergyModelsBase
using JuMP
using TimeStructures

const EMB = EnergyModelsBase
const TS  = TimeStructures

include("datastructures.jl")
include("model.jl")
include("checks.jl")

export NonDisRES
export RegHydroStor

end # module
