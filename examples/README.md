# Running the examples

You have to add the package `EnergyModelsRenewableProducers` to your current project in order to run the example.
It is not necessary to add the other used packages, as the example is instantiating itself.
How to add packages is explained in the *[Quick start](https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/manual/quick-start/)* of the documentation

You can run from the Julia REPL the following code:

```julia
# Import EnergyModelsRenewableProducers
using EnergyModelsRenewableProducers

# Get the path of the examples directory
exdir = joinpath(pkgdir(EnergyModelsRenewableProducers), "examples")

# Include the code into the Julia REPL to run the example of the NonDisRes node
include(joinpath(exdir, "simple_nondisres.jl"))

# Include the code into the Julia REPL to run the example of the Hydropower node
include(joinpath(exdir, "simple_hydro_power.jl"))
```
