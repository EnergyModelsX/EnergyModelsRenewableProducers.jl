# Running the examples

You have to add the package `EnergyModelsRenewableProducers` to your current project in order to run the example.
It is not necessary to add the other used packages, as the example is instantiating itself.
How to add packages is explained in the *[Quick start](https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/manual/quick-start/)* of the documentation

You can run from the Julia REPL the following code:

```julia
# Starts the Julia REPL
using EnergyModelsRenewableProducers
# Get the path of the examples directory
exdir = joinpath(pkgdir(EnergyModelsRenewableProducers), "examples")
# Include the code into the Julia REPL to run the first example of the NonDisRes node
include(joinpath(exdir, "simple_nondisres.jl"))
# Include the code into the Julia REPL to run the first example of the Hydropower node
include(joinpath(exdir, "simple_hydro_power.jl"))
```

> **Note**
>
> The example is not running yet, as the instantiation would require that the package [`EnergyModelsBase`](https://github.com/EnergyModelsX/EnergyModelsBase.jl) is registered.
> It is however possible to run the code directly from a local project in which the packages `TimeStruct`, `EnergyModelsBase`, `EnergyModelsRenewableProducers`, `HiGHS`, `JuMP`, and `PrettyTables` are loaded.
> In this case, you have to comment lines 2-7 out:
> ```julia
> # Activate the test-environment, where HiGHS is added as dependency.
> Pkg.activate(joinpath(@__DIR__, "../test"))
> # Install the dependencies.
> Pkg.instantiate()
> # Add the package EnergyModelsRenewableProducers to the environment.
> Pkg.develop(path=joinpath(@__DIR__, ".."))
> ```
