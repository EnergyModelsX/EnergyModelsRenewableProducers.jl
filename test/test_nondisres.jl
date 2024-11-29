@testset "NonDisRES" begin
    # Creation of the initial problem with the NonDisRES node
    wind = NonDisRES(
        "wind",
        FixedProfile(25),
        StrategicProfile([0.9, 0.4, 0.6, 0.8]),
        FixedProfile(10),
        FixedProfile(10),
        Dict(Power => 1),
    )
    case, modeltype = small_graph(source=wind, ops=SimpleTimes(4,1))

    # Run the model
    m = EMB.run_model(case, modeltype, OPTIMIZER)

    # Extraction of the time structure
    𝒯 = case[:T]

    # Run of the general tests
    general_tests(m)

    # Test that cap_use is correctly with respect to the profile.
    # - EMB.constraints_capacity(m, n::NonDisRES, 𝒯::TimeStructure, modeltype::EnergyModel)
    #   - 4 as we have 4 operational periods per strategic period and a single strategic
    #     period with curtailment
    @test sum(value.(m[:curtailment][wind, t]) > 0 for t ∈ 𝒯) == 4
    @test sum(
        value.(m[:cap_use][wind, t]) + value.(m[:curtailment][wind, t]) ≈
        EMRP.profile(wind, t) * value.(m[:cap_inst][wind, t]) for t ∈ 𝒯, atol ∈ TEST_ATOL
    ) == length(𝒯)
end
