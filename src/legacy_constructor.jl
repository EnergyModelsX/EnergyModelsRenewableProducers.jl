"""
    RegHydroStor(
        id::Any,
        rate_cap::TimeProfile,
        stor_cap::TimeProfile,
        has_pump::Bool,
        level_init::TimeProfile,
        level_inflow::TimeProfile,
        level_min::TimeProfile,
        opex_var::TimeProfile,
        opex_fixed::TimeProfile,
        stor_res::ResourceCarrier,
        input,
        output,
        Data,
    )

Original Legacy constructor for a regulated hydropower storage, with or without pumping capabilities.
This version is discontinued starting with Version 0.6.0. resulting in an error
It is replaced with the two new types [`HydroStor`](@ref) and [`PumpedHydroStor`](@ref)
to utilize the concept of multiple dispatch instead of logic.

See the *[documentation](https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/how-to/update-models/#Adjustments-from-0.4.0-to-0.6.x)*
for further information regarding how you can translate your existing model to the new model.

## Fields
- **`id`** is the name/identifyer of the node.
- **`rate_cap::TimeProfile`** is the installed installed rate capacity.
- **`stor_cap::TimeProfile`** is the installed storage capacity in the dam.
- **`has_pump::Bool`** states wheter the stored resource can flow in.
- **`level_init::TimeProfile`** is the initial stored energy in the dam.
- **`level_inflow::TimeProfile`** is the inflow of power per operational period.
- **`level_min::TimeProfile`** is the minimum fraction of the reservoir capacity that
  has to remain in the `HydroStorage` node.
- **`opex_var::TimeProfile`** are the variable operational expenses per GWh produced.
- **`opex_fixed::TimeProfile`** are the fixed operational costs of the storage caacity.
- **`stor_res::ResourceCarrier`** is the stored `Resource`.
- **`input::Dict{Resource, Real}`** are the stored and used resources. The values in the Dict
  are ratios describing the energy loss when using the pumps.
- **`output::Dict{Resource, Real}`** can only contain one entry, the stored resource.
- **`data::Array{Data}`** additional data (e.g. for investments). This value is conditional
  through the application of a constructor.
"""
function RegHydroStor(
    id::Any,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,
    has_pump::Bool,
    level_init::TimeProfile,
    level_inflow::TimeProfile,
    level_min::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input,
    output,
    Data,
)
    @error(
        "This implementation of a `RegHydroStor` will be discontinued in the near future.
        It is replaced with the type
            - `PumpedHydroStor` when considering a pumped hydro storage node or
            - `HydroStor` for a standard regulated hydro power plant.
        You can find the individual fields of these types in the documentation."
    )
end

"""
    HydroStor(
        id::Any,
        rate_cap::TimeProfile,
        stor_cap::TimeProfile,
        level_init::TimeProfile,
        level_inflow::TimeProfile,
        level_min::TimeProfile,
        opex_var::TimeProfile,
        opex_fixed::TimeProfile,
        stor_res::ResourceCarrier,
        input,
        output,
        Data,
    )

Legacy constructor for a regulated hydropower plant without pumping capabilities.
This version will be discontinued in the near future and replaced with the new version of
`HydroStor{StorageBehavior}` in which the parametric input defines the behavior of the
hydropower plant.
In addition, the introduction of `AbstractStorageParameters` allows for an improved
description of the individual capacities and OPEX contributions for the storage `level` and
`discharge` capacity.

See the *[documentation](https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/how-to/update-models/#Adjustments-from-0.4.0-to-0.6.x)*
for further information regarding how you can translate your existing model to the new model.

## Fields
- **`id`** is the name/identifyer of the node.
- **`rate_cap::TimeProfile`** is the installed installed rate capacity.
- **`stor_cap::TimeProfile`** is the installed storage capacity in the dam.
- **`level_init::TimeProfile`** is the initial stored energy in the dam.
- **`level_inflow::TimeProfile`** is the inflow of power per operational period.
- **`level_min::TimeProfile`** is the minimum fraction of the reservoir capacity that
  has to remain in the `HydroStorage` node.
- **`opex_var::TimeProfile`** are the variable operational expenses per GWh produced.
- **`opex_fixed::TimeProfile`** are the fixed operational costs of the storage caacity.
- **`stor_res::ResourceCarrier`** is the stored `Resource`.
- **`input::Dict{Resource, Real}`** are the stored and used resources. The values in the Dict
  are ratios describing the energy loss when using the pumps.
- **`output::Dict{Resource, Real}`** can only contain one entry, the stored resource.
- **`data::Array{Data}`** additional data (e.g. for investments). This value is conditional
  through the application of a constructor.
"""
function HydroStor(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,

    level_init::TimeProfile,
    level_inflow::TimeProfile,
    level_min::TimeProfile,

    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input::Dict{<:Resource, <:Real},
    output::Dict{<:Resource, <:Real},
)
    @warn(
        "The used implementation of a `HydroStor` will be discontinued in the near " *
        "future. The new implementation using the types the types `StorageBehavior` and " *
        "`AbstractStorageParameters` for describing a) the cyclic behavior and b) " *
        "the parameters for the `level` and `discharge` capacities.\n" *
        "In practice, two changes have to be incorporated: \n 1. `HydroStor{CyclicStrategic}()` " *
        "instead of `HydroStor` and \n 2. the application of `StorCapOpexFixed(stor_cap, opex_fixed)` " *
        "as 2ⁿᵈ field as well as `StorCapOpexVar(rate_cap, opex_var))` as 3ʳᵈ field. " *
        "2ⁿᵈ, 3ʳᵈ, 7ᵗʰ and 8ᵗʰ fields are removed.\n" *
        "See the documentation (https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/how-to/update-models/#Adjustments-from-0.4.0-to-0.6.x) " *
        "on how to update your model to the latest version.",
        maxlog = 1
    )

    return HydroStor{CyclicStrategic}(
        id,
        StorCapOpexFixed(stor_cap, opex_fixed),
        StorCapOpexVar(rate_cap, opex_var),
        level_init,
        level_inflow,
        level_min,
        stor_res,
        input,
        output,
        Data[],
    )
end
function HydroStor(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,

    level_init::TimeProfile,
    level_inflow::TimeProfile,
    level_min::TimeProfile,

    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input::Dict{<:Resource, <:Real},
    output::Dict{<:Resource, <:Real},
    data::Vector{Data},
)
    @warn(
        "The used implementation of a `HydroStor` will be discontinued in the near " *
        "future. The new implementation using the types the types `StorageBehavior` and " *
        "`AbstractStorageParameters` for describing a) the cyclic behavior and b) " *
        "the parameters for the `level` and `discharge` capacities.\n" *
        "In practice, two changes have to be incorporated: \n 1. `HydroStor{CyclicStrategic}()` " *
        "instead of `HydroStor` and \n 2. the application of `StorCapOpexFixed(stor_cap, opex_fixed)` " *
        "as 2ⁿᵈ field as well as `StorCapOpexVar(rate_cap, opex_var))` as 3ʳᵈ field. " *
        "2ⁿᵈ, 3ʳᵈ, 7ᵗʰ and 8ᵗʰ fields are removed.\n" *
        "See the documentation (https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/how-to/update-models/#Adjustments-from-0.4.0-to-0.6.x) " *
        "on how to update your model to the latest version.",
        maxlog = 1
    )

    return HydroStor{CyclicStrategic}(
        id,
        StorCapOpexFixed(stor_cap, opex_fixed),
        StorCapOpexVar(rate_cap, opex_var),
        level_init,
        level_inflow,
        level_min,
        stor_res,
        input,
        output,
        data,
    )
end

"""
    PumpedHydroStor(
        id::Any,
        rate_cap::TimeProfile,
        stor_cap::TimeProfile,
        level_init::TimeProfile,
        level_inflow::TimeProfile,
        level_min::TimeProfile,
        opex_var::TimeProfile,
        opex_fixed::TimeProfile,
        stor_res::ResourceCarrier,
        input,
        output,
        Data,
    )

Legacy constructor for a regulated  pumped hydropower storage plant.
This version will be discontinued in the near future and replaced with the new version of
`HydroStor{StorageBehavior}` in which the parametric input defines the behavior of the
hydropower plant.
In addition, the introduction of `AbstractStorageParameters` allows for an improved
description of the individual capacities and OPEX contributions for the pump capacity
(`charge`), storage `level` and `discharge` capacity.

See the *[documentation](https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/how-to/update-models/#Adjustments-from-0.4.0-to-0.6.x)*
for further information regarding how you can translate your existing model to the new model.

## Fields
- **`id`** is the name/identifyer of the node.
- **`rate_cap::TimeProfile`** is the installed installed rate capacity.
- **`stor_cap::TimeProfile`** is the installed storage capacity in the dam.
- **`level_init::TimeProfile`** is the initial stored energy in the dam.
- **`level_inflow::TimeProfile`** is the inflow of power per operational period.
- **`level_min::TimeProfile`** is the minimum fraction of the reservoir capacity that
  has to remain in the `HydroStorage` node.
- **`opex_var::TimeProfile`** are the variable operational expenses per GWh produced.
- **`opex_var_pump::TimeProfile`** are the variable operational expenses per GWh pumped
  into the storage.
- **`opex_fixed::TimeProfile`** are the fixed operational costs of the storage caacity.
- **`stor_res::ResourceCarrier`** is the stored `Resource`.
- **`input::Dict{Resource, Real}`** are the stored and used resources. The values in the Dict
  are ratios describing the energy loss when using the pumps.
- **`output::Dict{Resource, Real}`** can only contain one entry, the stored resource.
- **`data::Array{Data}`** additional data (e.g. for investments). This value is conditional
  through the application of a constructor.
"""
function PumpedHydroStor(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,

    level_init::TimeProfile,
    level_inflow::TimeProfile,
    level_min::TimeProfile,

    opex_var::TimeProfile,
    opex_var_pump::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input::Dict{<:Resource, <:Real},
    output::Dict{<:Resource, <:Real},
)
    @warn(
        "The used implementation of a `PumpedHydroStor` will be discontinued in the near " *
        "future. The new implementation using the types the types `StorageBehavior` and " *
        "`AbstractStorageParameters` for describing a) the cyclic behavior and b) " *
        "the parameters for the `level`, `charge`, and `discharge` capacities.\n" *
        "In practice, two changes have to be incorporated: \n 1. `PumpedHydroStor{CyclicStrategic}()` " *
        "instead of `PumpedHydroStor` and \n 2. the application of `StorCapOpexVar(rate_cap, opex_var_pump)` " *
        "as 2ⁿᵈ field, `StorCapOpexFixed(stor_cap, opex_fixed)` as 3ʳᵈ field, and" *
        "`StorCapOpexVar(rate_cap, opex_var))` as 4ᵗʰ field. " *
        "The previous 2ⁿᵈ, 3ʳᵈ, 7ᵗʰ, 8ᵗʰ, and 9ᵗʰ fields are removed.\n" *
        "See the documentation (https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/how-to/update-models/#Adjustments-from-0.4.0-to-0.6.x) " *
        "on how to update your model to the latest version.",
        maxlog = 1
    )

    return PumpedHydroStor{CyclicStrategic}(
        id,
        StorCapOpexVar(rate_cap, opex_var_pump),
        StorCapOpexFixed(stor_cap, opex_fixed),
        StorCapOpexVar(rate_cap, opex_var),
        level_init,
        level_inflow,
        level_min,
        stor_res,
        input,
        output,
        Data[],
    )
end
function PumpedHydroStor(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,

    level_init::TimeProfile,
    level_inflow::TimeProfile,
    level_min::TimeProfile,

    opex_var::TimeProfile,
    opex_var_pump::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input::Dict{<:Resource, <:Real},
    output::Dict{<:Resource, <:Real},
    data::Vector{Data},
)
    @warn(
        "The used implementation of a `PumpedHydroStor` will be discontinued in the near " *
        "future. The new implementation using the types the types `StorageBehavior` and " *
        "`AbstractStorageParameters` for describing a) the cyclic behavior and b) " *
        "the parameters for the `level`, `charge`, and `discharge` capacities.\n" *
        "In practice, two changes have to be incorporated: \n 1. `PumpedHydroStor{CyclicStrategic}()` " *
        "instead of `PumpedHydroStor` and \n 2. the application of `StorCapOpexVar(rate_cap, opex_var_pump)` " *
        "as 2ⁿᵈ field, `StorCapOpexFixed(stor_cap, opex_fixed)` as 3ʳᵈ field, and" *
        "`StorCapOpexVar(rate_cap, opex_var))` as 4ᵗʰ field. " *
        "The previous 2ⁿᵈ, 3ʳᵈ, 7ᵗʰ, 8ᵗʰ, and 9ᵗʰ fields are removed.\n" *
        "See the documentation (https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/how-to/update-models/#Adjustments-from-0.4.0-to-0.6.x) " *
        "on how to update your model to the latest version.",
        maxlog = 1
    )

    return PumpedHydroStor{CyclicStrategic}(
        id,
        StorCapOpexVar(rate_cap, opex_var_pump),
        StorCapOpexFixed(stor_cap, opex_fixed),
        StorCapOpexVar(rate_cap, opex_var),
        level_init,
        level_inflow,
        level_min,
        stor_res,
        input,
        output,
        data,
    )
end
