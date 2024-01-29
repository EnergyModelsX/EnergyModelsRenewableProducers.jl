# EnergyModelsRenewableProducers

[![Build Status](https://github.com/EnergyModelsX/EnergyModelsRenewableProducers.jl/workflows/CI/badge.svg)](https://github.com/EnergyModelsX/EnergyModelsRenewableProducers.jl/actions?query=workflow%3ACI)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/)
[![In Development](https://img.shields.io/badge/docs-dev-blue.svg)](https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/dev/)

`EnergyModelsRenewableProducers` is a package to model renewable power generation technologies.
It extends the [`EnergyModelsBase`](https://github.com/EnergyModelsX/EnergyModelsBase.jl) package with non-dispatchable power generation from sources such as wind turbines as well as modelling of hydro power.
It can also be used to see how a new node type can be developed.

## Usage

The usage of the package is best illustrated through the commented [`examples`](examples).
The examples are minimum working examples highlighting the individual new nodes and how they may impact the results.

## Cite

If you find `EnergyModelsRenewableProducers` useful in your work, we kindly request that you cite the following publication:

```bibtex
@article{boedal_2024,
  title = {Hydrogen for harvesting the potential of offshore wind: A {N}orth {S}ea case study},
  journal = {Applied Energy},
  volume = {357},
  pages = {122484},
  year = {2024},
  issn = {0306-2619},
  doi = {https://doi.org/10.1016/j.apenergy.2023.122484},
  url = {https://www.sciencedirect.com/science/article/pii/S0306261923018482},
  author = {Espen Flo B{\o}dal and Sigmund Eggen Holm and Avinash Subramanian and Goran Durakovic and Dimitri Pinel and Lars Hellemo and Miguel Mu{\~n}oz Ortiz and Brage Rugstad Knudsen and Julian Straus}
}
```

## Project Funding

The development of `EnergyModelsRenewableProducers` was funded by the Norwegian Research Council in the project [Clean Export](https://www.sintef.no/en/projects/2020/cleanexport/), project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)
