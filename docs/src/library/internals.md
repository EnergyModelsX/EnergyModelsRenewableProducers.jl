# Internals

## Contents
```@contents
Pages = ["internals.md]
```


## Optimization variables

The only new optimization variable added by this package, is `:curtailment[n, t]`. This is created by the method `create_node(m, N, T, n::NonDisRes, modeltype)` which is a method called from `EnergyModelsBase`. The variable represents the amount of energy *not* produced by node ``n`` `::NonDisRes` at operational period ``t``. 


## Constraints

### `NonDisRes`

``\texttt{:cap\_use}[n, t] + \texttt{:curtailment}[n, t] = n.\texttt{Profile}[t] \cdot \texttt{:cap\_inst}[n, t] ``


## Methods

```@docs
RenewableProducers.EMB.variables_node
RenewableProducers.EMB.create_node
RenewableProducers.EMB.check_node
```