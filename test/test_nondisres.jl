

# Test set for the non dispatchable renewable energy source type
@testset "NonDisRES" begin

    # Creation of the initial problem and the NonDisRES node
    case, modeltype = small_graph()
    wind = RP.NonDisRES("wind", FixedProfile(2), FixedProfile(0.9), 
        FixedProfile(10), FixedProfile(10), Dict(Power=>1), [])

    # Updating the nodes and the links
    push!(case[:nodes], wind)
    link = EMB.Direct(41, case[:nodes][4], case[:nodes][1], EMB.Linear())
    push!(case[:links], link)

    # Run the model
    m = EMB.run_model(case, modeltype, OPTIMIZER)

    # Extraction of the time structure
    𝒯 = case[:T]

    # Run of the general tests
    general_tests(m)

    # Check that the installed capacity variable corresponds to the provided values
    @testset "cap_inst" begin
        @test sum(value.(m[:cap_inst][wind, t]) == wind.Cap[wind] for t ∈ 𝒯) == length(𝒯)
    end
    
    @testset "cap_use bounds" begin
        # Test that cap_use is bounded by cap_inst.
        @test sum(value.(m[:cap_use][wind, t]) <= value.(m[:cap_inst][wind, t]) for t ∈ 𝒯) == length(𝒯)
            
        # Test that cap_use is set correctly with respect to the profile.
        @test sum(value.(m[:cap_use][wind, t]) <= wind.Profile[t] * value.(m[:cap_inst][wind, t])
                for t ∈ 𝒯) == length(𝒯)
    end
end
