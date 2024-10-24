# Test that the fields of a NonDisRES are correctly checked
# - check_node(n::NonDisRES, 𝒯, modeltype::EnergyModel)
@testset "Checks" begin

    # Set the global to true to suppress the error message
    EMB.TEST_ENV = true

    # Test that a wrong capacity is caught by the checks.
    wind = EMRP.NonDisRES(
        "wind",
        FixedProfile(-2),
        OperationalProfile([0.9, 0.4, 0.6, 0.8]),
        FixedProfile(10),
        FixedProfile(10),
        Dict(Power => 1),
    )
    case, modeltype = small_graph(source=wind, ops=SimpleTimes(4,1))
    @test_throws AssertionError EMB.run_model(case, modeltype, OPTIMIZER)

    # Test that a wrong fixed OPEX is caught by the checks.
    wind = EMRP.NonDisRES(
        "wind",
        FixedProfile(2),
        OperationalProfile([0.9, 0.4, 0.6, 0.8]),
        FixedProfile(10),
        FixedProfile(-10),
        Dict(Power => 1),
    )
    case, modeltype = small_graph(source=wind, ops=SimpleTimes(4,1))
    @test_throws AssertionError EMB.run_model(case, modeltype, OPTIMIZER)

    # Test that a wrong output dictionary is caught by the checks.
    wind = EMRP.NonDisRES(
        "wind",
        FixedProfile(2),
        OperationalProfile([0.9, 0.4, 0.6, 0.8]),
        FixedProfile(10),
        FixedProfile(10),
        Dict(Power => -1),
    )
    case, modeltype = small_graph(source=wind, ops=SimpleTimes(4,1))
    @test_throws AssertionError EMB.run_model(case, modeltype, OPTIMIZER)

    # Test that a wrong profile is caught by the checks.
    wind = EMRP.NonDisRES(
        "wind",
        FixedProfile(2),
        OperationalProfile([-0.9, 0.4, 0.6, 0.8]),
        FixedProfile(10),
        FixedProfile(10),
        Dict(Power => 1),
    )
    case, modeltype = small_graph(source=wind, ops=SimpleTimes(4,1))
    @test_throws AssertionError EMB.run_model(case, modeltype, OPTIMIZER)
    wind = EMRP.NonDisRES(
        "wind",
        FixedProfile(2),
        OperationalProfile([0.9, 0.4, 1.6, 0.8]),
        FixedProfile(10),
        FixedProfile(10),
        Dict(Power => 1),
    )
    case, modeltype = small_graph(source=wind, ops=SimpleTimes(4,1))
    @test_throws AssertionError EMB.run_model(case, modeltype, OPTIMIZER)

    # Set the global again to false
    EMB.TEST_ENV = false
end

@testset ":profile and :curtailment" begin
    # Creation of the initial problem with the NonDisRES node
    wind = EMRP.NonDisRES(
        "wind",
        FixedProfile(25),
        OperationalProfile([0.9, 0.4, 0.6, 0.8]),
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
    @test sum(
        value.(m[:cap_use][wind, t]) + value.(m[:curtailment][wind, t]) ≈
        EMRP.profile(wind, t) * value.(m[:cap_inst][wind, t]) for t ∈ 𝒯, atol ∈ TEST_ATOL
    ) == length(𝒯)
end
