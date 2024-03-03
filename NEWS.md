# Release notes

## Version 0.5.4 (2024-03-XX)

### Examples

* Fixed a bug when running the examples from a non-cloned version of `EnergyModelsRenewableProducers`.
* This was achieved through a separate Project.toml in the examples.

### NonDIsRes node

* Moved the capacity constraints through the profile to the function `EMB.constraints_capacity(n::NonDisRES, ...)`, and hence, removed the function `EMB.create_node(n::NonDisRES, ...)`.

### Minor updates

* Added some checks and tests to the checks.
* Restructured the test folder.

## Version 0.5.3 (2024-01-30)

* Updated the restrictions on the fields of individual types to be consistent.
* Added option to not include the field `data` for the individual introduced `Node`s.

## Version 0.5.2 (2024-01-19)

* Updated the documenation to be in line with the updated done in `EnergyModelsBsae`.
* Moved `RegHydroStor` to a new file, `legacy_constructors.jl` to highlight that a user should use the new types, namely `HydroStor` and `PumpedHydroStor`.

## Version 0.5.1 (2024-01-17)

* Update the method `constraints_level` to match the signature updates for these methods in `EnergyModelsBase`. This includes renaming `constraints_level` to `constraints_level_sp`.
* Moved the function to `EMB.constraints_level_sp` to avoid problems.

## Version 0.5.0 (2023-12-18)

### Adjustment to release in EMB 0.6.0

* Adjusted the code for the new release.
* Implementation of support for `RepresentativePeriods` for `HydroStorage` nodes.

## Version 0.4.2 (2023-09-01)

### Create a variable :spill for hydro storage node

* This variable enables hydro storage nodes to spill water from the reservoir without
   producing energy.

## Version 0.4.1 (2023-08-31)

### Split the hydro storage node into to separate nodes

* Split `RegHydroStor` into to types `PumpedHydroStor` and `HydroStor`. Both are subtypes
 of the new abstract type `HydroStorage <: EMB.Storage`.
* Fix: variational OPEX for `HydroStor` now depends on `flow_out` instead of
 `flow_in`. The new type `PumpedHydroStor` has a separate parameter for variational OPEX
 for the pumps, which depends on `flow_in`.

## Version 0.4.0 (2023-06-06)

### Switch to TimeStruct.jl

* Switched the time structure representation to [TimeStruct.jl](https://github.com/sintefore/TimeStruct.jl).
* TimeStruct.jl is implemented with only the basis features that were available in TimesStructures.jl. This implies that neither operational nor strategic uncertainty is included in the model.

Version 0.3.0 (2023-05-30)

* Adjustment to changes in `EnergyModelsBase` v0.4.0 related to extra input data.

## Version 0.2.2 (2023-05-15)

* Adjustment to changes in `EnergyModelsBase` v 0.3.3 related to the calls for the constraint functions.

## Version 0.2.1 (2023-02-03)

* Take the examples out to the folder `examples`.

## Version 0.2.0 (2023-02-03)

### Adjustmends to updates in EnergyModelsBase

Adjustment to version 0.3.0, namely:

* Changed type (`Node`) calls in tests to be consistent with version 0.3.0.
* Removal of the type `GlobalData` and replacement with fields in the type `OperationalModel` in all tests.
* Changed type structure to be consistent with EMB version 0.3.0.
* Substitution of certain constraints in `create_node` through functions which utilize dispatching on `node` types.
* Changed the input to the function `variables_node`.

## Version 0.1.3 (2022-12-12)

### Internal release

* Renamed to follow common prefix naming scheme.
* Update README.

## Version 0.1.2 (2022-12-02)

* Minor test fixes in preparation of internal release.

## Version 0.1.1 (2021-09-07)

### Changes in naming

* Major changes in both variable and parameter naming, check the commit message for an overview.
* Change of structure in composite type "RegHydroStor".

## Version 0.1.0 (2021-08-23)

* Initial version with inclusion of nodes for:
  * nondispatchable renewable energy sources (NonDisRES) and
  * regulated hydro generation (RegHydroStor, can be used for pumped hydro storage).
