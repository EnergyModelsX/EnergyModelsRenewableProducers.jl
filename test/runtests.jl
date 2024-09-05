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
    @testset "RP - Non-dispatchable renewable energy source" begin
        include("test_nondisres.jl")
    end

    @testset "RP - Hydropower" begin
        include("test_hydro.jl")
    end

    @testset "RP - examples" begin
        include("test_examples.jl")
    end

    redirect_stdio(stdout=devnull, stderr=devnull) do
        @testset "RP - constructors" begin
            include("test_constructors.jl")
        end
    end
end
