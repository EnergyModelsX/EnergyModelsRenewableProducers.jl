# [Contribute to EnergyModelsRenewableProducers](@id how_to-con)

Contributing to `EnergyModelsRenewableProducers` can be achieved in several different ways.

## [File a bug report](@id how_to-con-bug_rep)

Another approach to contributing to `EnergyModelsRenewableProducers` is through filing a bug report as an [_issue_](https://github.com/EnergyModelsX/EnergyModelsRenewableProducers.jl/issues/new) when unexpected behaviour is occuring.

When filing a bug report, please follow the following guidelines:

1. Be certain that the bug is a bug and originating in `EnergyModelsRenewableProducers`:
    - If the problem is within the results of the optimization problem, please check first that the nodes are correctly linked with each other.
      Frequently, missing links (or wrongly defined links) restrict the transport of energy/mass.
      If you are certain that all links are set correctly, it is most likely a bug in `EnergyModelsRenewableProducers` and should be reported.
    - If the problem occurs in model construction, it is most likely a bug in either `EnergyModelsBase` or `EnergyModelsRenewableProducers` and should be reported in the respective package.
      The error message of Julia should provide you with the failing function and whether the failing function is located in `EnergyModelsBase` or `EnergyModelsRenewableProducers`.
      It can occur, that the last shown failing function is within `JuMP` or `MathOptInterface`.
      In this case, it is best to trace the error to the last called `EnergyModelsBase` or `EnergyModelsRenewableProducers` function.
    - If the problem is only appearing for specific solvers, it is most likely not a bug in `EnergyModelsRenewableProducers`, but instead a problem of the solver wrapper for `MathOptInterface`.
      In this case, please contact the developers of the corresponding solver wrapper.
2. Label the issue as bug, and
3. Provide a minimum working example of a case in which the bug occurs.

## [Feature requests](@id how_to-con-feat_req)

`EnergyModelsRenewableProducers` includes several new nodal descriptions for renewable energy producers.
However, there can be a demand for additional requirements for the existing nodes or for new descriptions which fall below the umbrella of renewable energy producers.
In this case, you can contribute through a feature request.

Feature requests for `EnergyModelsRenewableProducers` should follow the guidelines developed for [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/how-to/contribute/).

!!! note
    `EnergyModelsRenewableProducers` is slightly different than `EnergyModelsBase`.

    Contrary to the other package, we consider that it is beneficial to have all potential features of renewable energy production within `EnergyModelsRenewableProducers`.
    Hence, if you have a requirement for a new nodal description, do not hesitate to create an [_issue_](https://github.com/EnergyModelsX/EnergyModelsRenewableProducers.jl/issues/new).
