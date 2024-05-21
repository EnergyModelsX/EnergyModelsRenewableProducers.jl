
struct Inflow <: EMB.Source  # kan evnt bygge på NonDisRES
    id::Any
    cap::TimeProfile # Inflow [m3/s --> eller Mm3/h]
    profile::TimeProfile    # denne er med i NonDisRES
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    output::Dict{<:Resource,<:Real}
    data::Vector{Data}
end

function Inflow(
    id::Any,
    cap::TimeProfile,
    profile::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    output::Dict{<:Resource,<:Real},
)
    return Inflow(id, cap, profile, opex_var, opex_fixed, output, Data[])
end

struct HydroReservoir <: EMB.Storage # kan evnt bygge på HydroStor
    id::Any
    rate_cap::TimeProfile # inflow/outflow cap
    stor_cap::TimeProfile # can be read from the vol_head profile...
    level_init::TimeProfile # 
    #level_min::TimeProfile # Lowest permitted regulated water level
    #level_max::TimeProfile # Highest permitted regulated water level
    opex_var::TimeProfile # Variable operational costs
    opex_fixed::TimeProfile # Fixed operational costs
    stor_res::ResourceCarrier # Water
    #vol_head::Dict{<:Real, <:Real} # New,  relation between volume and head (Mm3/meter)
    #water_value::Dict{<: Int, <:Dict{<:Real, <:Real}} # linear constraints binding the value of the storage
    input::Dict{<:Resource,<:Real} # Water
    output::Dict{<:Resource,<:Real} # Water
    data::Vector{Data}
end
function HydroReservoir(
    id::Any,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,
    level_init::TimeProfile,
    #level_min::TimeProfile,
    #level_max::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    #vol_head::Dict{<:Real, <:Real},
    #water_value::Union{<:Real, <:Real},
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
)
    return HydroReservoir(
        id,
        rate_cap,
        stor_cap,
        level_init,
        opex_var,
        opex_fixed,
        stor_res,
        input,
        output,
        Data[],
    )
end

struct HydroStation <: EMB.NetworkNode # plant or pump or both? 
    id::Any
    #power_cap::TimeProfile # maximum production MW/(time unit)
    cap::TimeProfile # maximum discharge mm3/(time unit)
    pq_curve::Dict{<:Resource, <:Vector{<:Real}} # Production and discharge ratio [MW / m3/s]
    #pump_power_cap::TimeProfile #maximum production MW
    #pump_disch_cap::TimeProfile #maximum discharge mm3/time unit
    #pump_pq_curve::Dict{<:Real, <:Real}
    #prod_min::TimeProfile # Minimum production [MW]
    #prod_max::TimeProfile # Maximum production [MW]
    #cons_min::TimeProfile # Minimum consumption [MW]
    #cons_max::TimeProfile # Maximum consumption [MW]
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    input::Dict{<:Resource,<:Real}
    output::Dict{<:Resource,<:Real}
    η::Vector{Real}
    data::Vector{Data}
end
function HydroStation(
    id::Any,
    #power_cap::TimeProfile,
    cap::TimeProfile,
    pq_curve::Dict{<:Resource, <:Vector{<:Real}},
    #pq_curve::Dict{<:Real, <:Real},
    #pump_power_cap::TimeProfile,
    #pump_disch_cap::TimeProfile,
    #pump_pq_curve::Dict{<:Real, <:Real},
    #prod_min::TimeProfile,
    #prod_max::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
)
    return HydroStation(id, cap, pq_curve, opex_var, opex_fixed, input, output, Real[], Data[])
end

struct HydroGate <: EMB.NetworkNode
    id::Any
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    input::Dict{<:Resource,<:Real}
    output::Dict{<:Resource,<:Real}
    data::Vector{Data}
end
function HydroGate(
    id::Any,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
)
    return HydroGate(id, cap, opex_var, opex_fixed, input, output, Data[])
end

function Inflow(
    id::Any,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    output::Dict{<:Resource,<:Real},
)
    return Inflow(id, cap, profile, opex_var, opex_fixed, output, Data[])
end

"""
    profile(n::Inflow, t)

Returns the profile of a node `n` of type `NonDisRES` at operational period `t`.
"""
profile(n::Inflow, t) = n.profile[t]

"""
    level_init(n::HydroReservoir, t)

Returns the initial level of a node `n` of type `HydroReservoir` at operational period `t`
"""
level_init(n::HydroReservoir, t) = n.level_init[t]

"""
    level_init(n::HydroStation, t)

Returns the pq_curve of a node `n` of type `HydroStation` 
"""
pq_curve(n::HydroStation) = n.pq_curve

pq_curve(n::HydroStation, p::Resource) = n.pq_curve[p]