
struct Inflow <: EMB.Source  # kan evnt bygge på NonDisRES
    id::Any
    cap::TimeProfile # Inflow [m3/s --> eller Mm3/h]
   # profile::TimeProfile    # denne er med i NonDisRES
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    output::Dict{<:Resource, <:Real}
    data::Vector{Data}
end
function Inflow(
    id::Any,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    output::Dict{<:Resource, <:Real},
    )
    return Inflow(    
        id,
        cap,
        opex_var,
        opex_fixed,
        output,
        Data[],
        )
end

struct HydroReservoir <: EMB.Storage # kan evnt bygge på HydroStor
    id::Any
    #rate_cap::TimeProfile
    stor_cap::Real # can be read from the vol_head profile...
    level_init::TimeProfile # level_inflow::TimeProfile
    level_min::TimeProfile # Lowest permitted regulated water level
    level_max::TimeProfile # Highest permitted regulated water level
    opex_var::TimeProfile # Variable operational costs
    opex_fixed::TimeProfile # Fixed operational costs
    stor_res::ResourceCarrier # Water
    vol_head::Dict{<:Real, <:Real} # New,  relation between volume and head (Mm3/meter)
    water_value::Dict{<: Int, <:Dict{<:Real, <:Real}} # linear constraints binding the value of the storage
    input::Dict{<:Resource, <:Real} # Water
    output::Dict{<:Resource, <:Real} # Water
    data::Vector{Data}
end
function HydroReservoir(
    id::Any,
    stor_cap::Real,
    level_init::TimeProfile,
    level_min::TimeProfile,
    level_max::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    vol_head::Dict{<:Real, <:Real},
    water_value::Union{<:Real, <:Real},
    input::Dict{<:Resource, <:Real},
    output::Dict{<:Resource, <:Real},
)
return HydroReservoir(
    id,
    stor_cap,
    level_init,
    level_min,
    level_max,
    opex_var,
    opex_fixed,
    stor_res,
    vol_head,
    water_value,
    input,
    output,
    Data[],
)

end

struct HydroStation <: EMB.NetworkNode # plant or pump or both? 
    id::Any
    power_cap::TimeProfile # maximum production MW/(time unit)
    disch_cap::TimeProfile # maximum discharge mm3/(time unit)
    pq_curve::Dict{<:Real, <:Real} # Production and discharge ratio [MW / m3/s]
    pump_power_cap::TimeProfile #maximum production MW
    Pump_disch_cap::TimeProfile #maximum discharge mm3/time unit
    pump_pq_curve::Dict{<:Real, <:Real}
    prod_min::TimeProfile # Minimum production [MW]
    prod_max::TimeProfile # Maximum production [MW]
    #cons_min::TimeProfile # Minimum consumption [MW]
    #cons_max::TimeProfile # Maximum consumption [MW]
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    input::Dict{<:Resource, <:Real}
    output::Dict{<:Resource, <:Real}
    data::Vector{Data}
end
function HydroStation(
    id::Any,
    power_cap::TimeProfile,
    disch_cap::TimeProfile,
    pq_curve::Dict{<:Real, <:Real},
    pump_power_cap::TimeProfile,
    Pump_disch_cap::TimeProfile,
    pump_pq_curve::Dict{<:Real, <:Real},
    prod_min::TimeProfile,
    prod_max::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    input::Dict{<:Resource, <:Real},
    output::Dict{<:Resource, <:Real},
)
return HydroStation(
    id,        
    power_cap,
    disch_cap,
    pq_curve,
    pump_power_cap,
    Pump_disch_cap,
    pump_pq_curve,
    prod_min,
    prod_max,
    opex_var,
    opex_fixed,
    input,
    output,
    Data[],
)
end

struct HydroGate <: EMB.NetworkNode 
    id::Any
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    input::Dict{<:Resource, <:Real}
    output::Dict{<:Resource, <:Real}
    data::Vector{Data}
end
function HydroGate(
    id::Any,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    input::Dict{<:Resource, <:Real},
    output::Dict{<:Resource, <:Real},
)
return HydroGate(
    id,
    cap,
    opex_var,
    opex_fixed,
    input,
    output,
    Data[]
)
end

# link -> waterway
# kan man kapasitetsbegrense links? og derav slippe å benytte HydroGate?
# kan man legge til tidsforsinkelser
# andre begrensninger?


