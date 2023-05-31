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
using TimeStructures

const EMB = EnergyModelsBase
const TS  = TimeStructures

include("datastructures.jl")
include("model.jl")
include("checks.jl")

export NonDisRES
export RegHydroStor

end # module
