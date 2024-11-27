module EMIExt

using EnergyModelsBase
using EnergyModelsRenewableProducers
using EnergyModelsInvestments
using JuMP
using TimeStruct

const EMB = EnergyModelsBase
const EMRP = EnergyModelsRenewableProducers
const EMI = EnergyModelsInvestments
const TS = TimeStruct

include("checks.jl")
include("model.jl")
include("utils.jl")
include("constraint_functions.jl")

end
