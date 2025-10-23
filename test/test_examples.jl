@testset "Examples" begin
    using Logging
    # Get the global logger and set the loglevel to Warn
    logger_org = global_logger()
    logger_new = ConsoleLogger(Warn)
    global_logger(logger_new)

    ENV["EMX_TEST"] = true # Set flag for example scripts to check if they are run as part of the tests
    exdir = joinpath(@__DIR__, "..", "examples")
    files = filter(endswith(".jl"), readdir(exdir))
    for file ∈ files
        @testset "Example $file" begin
            redirect_stdio(stdout = devnull) do
                include(joinpath(exdir, file))
            end
            @test termination_status(m) == MOI.OPTIMAL
        end
    end
    Pkg.activate(@__DIR__)

    # Reset the loglevel
    global_logger(logger_org)
end