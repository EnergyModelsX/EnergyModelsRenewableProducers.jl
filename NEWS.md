# RenewableProducers changelog

Version 0.3.0 (2023-05-30)
--------------------------
 * Adjustment to changes in `EnergyModelsBase` v0.4.0 related to extra input data
 
Version 0.2.2 (2023-05-15)
--------------------------
 * Adjustment to changes in `EnergyModelsBase` v 0.3.3 related to the calls for the constraint functions

Version 0.2.1 (2023-02-03)
--------------------------
* Take the examples out to the folder `examples`.

Version 0.2.0 (2023-02-03)
--------------------------
### Adjustmends to updates in EnergyModelsBase
Adjustment to version 0.3.0, namely:
* Changed type (`Node`) calls in tests to be consistent with version 0.3.0
* Removal of the type `GlobalData` and replacement with fields in the type `OperationalModel` in all tests
* Changed type structure to be consistent with EMB version 0.3.0
* Substitution of certain constraints in `create_node` through functions which utilize dispatching on `node` types
* Changed the input to the function `variables_node`

Version 0.1.3 (2022-12-12)
--------------------------
### Internal release
* Renamed to follow common prefix naming scheme
* Update README

Version 0.1.2 (2022-12-02)
--------------------------
* Minor test fixes in preparation of internal release
  
Version 0.1.1 (2021-09-07)
--------------------------
### Changes in naming
* Major changes in both variable and parameter naming, check the commit message for an overview
* Change of structure in composite type "RegHydroStor"

Version 0.1.0 (2021-08-23)
--------------------------
* Initial version with inclusion of nodes for:
    * nondispatchable renewable energy sources (NonDisRES) 
    * regulated hydro generation (RegHydroStor, can be used for pumped hydro storage)