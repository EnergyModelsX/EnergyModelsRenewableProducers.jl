# Test that the fields of a WindResource are correctly checked

@testset "object creation" begin

    # Set the global to true to suppress the error message
    EMB.TEST_ENV = true

    my_power_curve = Array([4 0; 10 0.3; 20 1; 25 1; 28 0])
    my_wind_speed =
        OperationalProfile([0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30])
    my_windpower_expected = OperationalProfile([0, 0, 0])
    #my_wind_direction = FixedProfile(0)
    #my_turbulence = FixedProfile(0.2)
    #TODO: update test once wind direction and turbulence are implemented

    # Creation with wrong parameter type throws error
    @test_throws MethodError wind_resource = EMRP.WindResource(
        wind_speed = 14, # wrong
        wind_direction = nothing,
        turbulence = nothing,
        height = 80,
    )
    @test_throws MethodError wind_plant = EMRP.WindPowerPlant(
        power_curve = my_power_curve,
        turbine_height = [1, 2],
        shape = nothing,
    )

    # Test creation is OK
    wind_resource = EMRP.WindResource(
        wind_speed = my_wind_speed,
        wind_direction = nothing,
        turbulence = nothing,
        height = 80,
    )
    wind_plant = EMRP.WindPowerPlant(
        power_curve = my_power_curve,
        turbine_height = 100,
        shape = nothing,
        roughness_length = 0.001,
    )
    @test wind_resource.height == 80
    @test wind_plant.turbine_height == 100

    windpower_available = EMRP.wind_power_from_speed(wind_plant, wind_resource)

    @test windpower_available.vals[1] == 0
    @test windpower_available.vals[2] == 0
    @test windpower_available.vals[5] > 0 # wind speed > 4

    # Creation of the initial problem with the NonDisRES node
    wind = EMRP.NonDisRES(
        "wind",
        FixedProfile(25),  # cap
        windpower_available,  # profile
        FixedProfile(10),  # fixed opex
        FixedProfile(10),  # var opex
        Dict(Power => 1),  # output
    )
    case, modeltype = small_graph(source = wind, ops = SimpleTimes(4, 1))

    # Set the global again to false
    EMB.TEST_ENV = false
end
