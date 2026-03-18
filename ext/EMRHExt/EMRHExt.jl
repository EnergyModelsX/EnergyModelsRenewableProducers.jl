module EMRHExt

using EnergyModelsBase
using EnergyModelsRenewableProducers
using EnergyModelsRecedingHorizon
using JuMP
using TimeStruct

const EMB = EnergyModelsBase
const EMRP = EnergyModelsRenewableProducers
const EMRH = EnergyModelsRecedingHorizon
const TS = TimeStruct

include("constraint_functions.jl")

end
