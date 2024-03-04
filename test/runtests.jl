using EnergyModelsBase
using EnergyModelsRenewableProducers
using HiGHS
using JuMP
using Test
using TimeStruct

const EMB = EnergyModelsBase
const EMRP = EnergyModelsRenewableProducers

@testset "RenewableProducers" begin
    include("utils.jl")
    include("test_nondisres.jl")
    include("test_hydro.jl")
    include("test_examples.jl")
end
