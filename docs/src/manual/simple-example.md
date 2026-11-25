# [Examples](@id man-exampl)

For the content of the example, see the *[examples](https://github.com/EnergyModelsX/EnergyModelsRenewableProducers.jl/tree/main/examples)* directory in the project repository.

## The package is installed with `] add`

From the Julia REPL, run

```julia
# Starts the Julia REPL
julia> using EnergyModelsRenewableProducers
# Get the path of the examples directory
julia> exdir = joinpath(pkgdir(EnergyModelsRenewableProducers), "examples")
# Include the code into the Julia REPL to run the first example of the NonDisRES node
julia> include(joinpath(exdir, "simple_nondisres.jl"))
# Include the code into the Julia REPL to run the first example of the Hydropower node
julia> include(joinpath(exdir, "simple_hydro_power.jl"))
# Include the code into the Julia REPL to run the example of the detailed hydropower nodes
julia> include(joinpath(exdir, "detailed_hydro_power.jl"))
# Include the code into the Julia REPL to run the example of the battery storage
julia> include(joinpath(exdir, "simple_battery.jl"))
```

## The code was downloaded with `git clone`

The examples can then be run from the terminal with

```shell script
/path/to/EnergyModelsRenewableProducers.jl/examples $ julia simple_nondisres.jl
/path/to/EnergyModelsRenewableProducers.jl/examples $ julia simple_hydro_power.jl
/path/to/EnergyModelsRenewableProducers.jl/examples $ julia detailed_hydro_power.jl
/path/to/EnergyModelsRenewableProducers.jl/examples $ julia simple_battery.jl
```
