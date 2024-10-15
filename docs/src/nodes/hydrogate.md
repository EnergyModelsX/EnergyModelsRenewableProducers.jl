# [Hydro gate node](@id nodes-hydro_gate)

The [`HydroReservoir`](@ref), [`HydroGate`](@ref), [`HydroGenerator`](@ref), and [`HydroPump`](@ref) should be used for detailed hydropower modeling.
Unlike [`HydroStorage`](@ref), [`HydroReservoir`](@ref) can have water as the stored resource.
[`HydroGenerator`](@ref) can produce electricity by moving water to a lower reservoir or the ocean that should be represented as a [`RefSink`](@extref EnergyModelsBase.RefSink).
Likewise, [`HydroPump`](@ref) can consume electricity by moving water to a higher reservoir.
[`HydroGate`](@ref) can discharge water to lower reservoirs without producing electricity, for example due to spillage or environmental restrictions in the water course.

## [Introduced type and its field](@id nodes-hydro_gate-fields)

### [Standard fields](@id nodes-hydro_gate-fields-stand)

### [Additional fields](@id nodes-hydro_gate-fields-new)

## [Mathematical description](@id nodes-hydro_gate-math)

### [Variables](@id nodes-hydro_gate-math-var)

#### [Standard variables](@id nodes-hydro_gate-math-var-stand)

#### [Additional variables](@id nodes-hydro_gate-math-add)

### [Constraints](@id nodes-hydro_gate-math-con)

#### [Standard constraints](@id nodes-hydro_gate-math-con-stand)

#### [Additional constraints](@id nodes-hydro_gate-math-con-add)

##### [Constraints calculated in `create_node`](@id nodes-hydro_gate-math-con-add-node)

##### [Level constraints](@id nodes-hydro_gate-math-con-add-level)
