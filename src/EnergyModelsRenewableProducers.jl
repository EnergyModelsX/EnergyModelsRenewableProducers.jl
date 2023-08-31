"""
Main module for `EnergyModelsRenewableProducers.jl`.

This module implements two types (Nodes) with constraints.
 - [`NonDisRes`](@ref) is a subtype of `Source` and represents a
   non-dispatchable renewable producer, as wind, solar etc.
 - [`RegHydroStor`](@ref) is a subtype of `Storage` represents a regulated hydro storage.
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

export NonDisRES
export RegHydroStor, PumpedHydroStor, HydroStor

end # module
