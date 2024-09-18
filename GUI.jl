# Starts the Julia REPL
using Revise
using Pkg
using EnergyModelsGUI

# Get the path of the examples directory
#exdir = joinpath(pkgdir(EnergyModelsGUI), "examples")
exdir = joinpath(".", "examples")

# Activate project for the examples in the EnergyModelsGUI repository
Pkg.activate(exdir)
Pkg.instantiate()

# Include the code into the Julia REPL to run the following example
include(joinpath(exdir, "testExample.jl"))
