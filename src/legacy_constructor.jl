"""
Legacy constructor for a regulated hydropower storage, with or without pumping \
capabilities. This version will be discontinued in the near future and is already replaced \
with the two new types `HydroStor` and `PumpedHydroStor`.

If you are creating a new model, it is advised to directly use the types `HydroStor` and \
`PumpedHydroStor`.

## Fields
- **`id`** is the name/identifyer of the node.\n
- **`rate_cap::TimeProfile`**: installed capacity.\n
- **`stor_cap::TimeProfile`** Initial installed storage capacity in the dam.\n
- **`has_pump::Bool`** states wheter the stored resource can flow in.\n
- **`level_init::TimeProfile`** Initial energy stored in the dam, in units of power.\n
- **`level_inflow::TimeProfile`** Inflow of power per operational period.\n
- **`level_min::TimeProfile`** Minimum fraction of the reservoir capacity that can be left.\n
- **`opex_var::TimeProfile`** Operational cost per GWh produced.\n
- **`opex_fixed::TimeProfile`** Fixed operational costs.\n
- **`stor_res::ResourceCarrier`** is the stored `Resource`.\n
- **`input::Dict{Resource, Real}`** the stored and used resources. The \
values in the Dict is a ratio describing the energy loss when using the pumps.\n
- **`output::Dict{Resource, Real}`** can only contain one entry, the stored resource.\n
- **`data::Array{Data}`** additional data (e.g. for investments).\n
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
    @warn(
        "This implementation of a `RegHydroStor` will be discontinued in the near future. \n
        It is replaced with the type
            - `PumpedHydroStor` when considering a pumped hydro storage node or
            - `HydroStor` for a standard regulated hydro power plant.
        You can find the individual fields of these types in the documentation."
    )

    if has_pump
        return PumpedHydroStor(
            id,
            rate_cap,
            stor_cap,
            level_init,
            level_inflow,
            level_min,
            FixedProfile(0),
            opex_var,
            opex_fixed,
            stor_res,
            input,
            output,
            Data,
        )
    else
        return HydroStor(
            id,
            rate_cap,
            stor_cap,
            level_init,
            level_inflow,
            level_min,
            opex_fixed,
            stor_res,
            input,
            output,
            Data,
        )
    end
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
