# Examples

For the content of the example, see the *[examples](https://gitlab.sintef.no/clean_export/EnergyModelsRenewableProducers.jl/-/tree/main/examples)* directory in the project repository.

## The package is installed with `] add`

From the Julia REPL, run

```julia
# Starts the Julia REPL
julia> using EnergyModelsRenewableProducers
# Get the path of the examples directory
julia> exdir = joinpath(pkgdir(EnergyModelsRenewableProducers), "examples")
# Include the code into the Julia REPL to run the first example of the NonDisRes node
julia> include(joinpath(exdir, "simple_nondisres.jl"))
# Include the code into the Julia REPL to run the first example of the Hydropower node
julia> include(joinpath(exdir, "simple_hydro_power.jl"))
```

## The code was downloaded with `git clone`

The examples can then be run from the terminal with

```shell script
~/../EnergyModelsRenewableProducers.jl/examples $ julia simple_nondisres.jl
~/../EnergyModelsRenewableProducers.jl/examples $ julia simple_hydro_power.jl
```
