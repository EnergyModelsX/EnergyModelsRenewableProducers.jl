""" Inflow to a hydropower system.

# Fields
- **`id`** is the name/identifyer of the node.\n
- **`cap::TimeProfile`** is the maximum capacity.\n
- **`profile::TimeProfile`** is the inflow in each operational period .\n
- **`opex_var::TimeProfile`** is the variational operational costs per unit water provided.\n
- **`opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`output::Dict{Resource, Real}`** are the provided `Resource`s, normally Water.\n
- **`data::Vector{Data}`** is the additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.

"""
struct Inflow <: EMB.Source  
    id::Any
    cap::TimeProfile # Vurder om denne skal representere årlig snitt. tilsig
    profile::TimeProfile    # Inflow [m3/s --> eller Mm3/h] , vurder om denne bør endres til å være en andel av årlig tilsig (utfordeling av cap?)
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


""" A regulated hydropower reservoir, modelled as a `Storage` node.

## Fields
- **`id`** is the name/identifyer of the node.\n
- **`rate_cap::TimeProfile`**: is the installed rate capacity, that is e.g. power or mass flow..\n
- **`stor_cap::TimeProfile`** Initial installed storage capacity in the dam.\n
- **`level_init::TimeProfile`** Initial water stored in the reservoir, in units of Mm3.\n
- **`opex_var::TimeProfile`** Operational cost per GWh produced.\n
- **`opex_fixed::TimeProfile`** Fixed operational costs. Currently used to value the reservoir filling at the end of the planning period.\n
- **`stor_res::ResourceCarrier`** is the stored `Resource`.\n
- **`input::Dict{Resource, Real}`** the stored and used resources.\n
- **`output::Dict{Resource, Real}`** can only contain one entry, the stored resource.\n
- **`data::Vector{Data}`** additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.
"""

struct HydroReservoir{T} <: EMB.Storage{T} # kan evnt bygge på HydroStor
    id::Any
    rate_cap::TimeProfile # inflow/outflow cap --- NB: forstå hva dette egnetlig er og om det må være med videre!!
    stor_cap::TimeProfile # can be read from the vol_head profile...
    level_init::TimeProfile# 
    level_min::TimeProfile # Lowest permitted regulated water level
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
    level_min::TimeProfile,
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
        level_min,
        opex_var,
        opex_fixed,
        stor_res,
        input,
        output,
        Data[],
    )
end


# TODO define power cap ?
# TODO check if opex var is dependent on discharge or power produced, update to cost/energy  
# TODO make pump module
# TODO add minimum release? eller skal dette settes opp med bruk av HydroGate?

""" A regular hydropower plant, modelled as a `NetworkNode` node.

## Fields
- **`id`** is the name/identifier of the node.\n
- **`cap::TimeProfile`** is the installed discharge capacity.\n
- **`pq_curve::Dict{<:Resource, <:Vector{<:Real}}` describes the relationship between power and discharge (water).\
requires one input resource (usually Water) and two output resources (usually Water and Power) to be defined \
where the input resource also is an output resource. \n
- **`opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`input::Dict{<:Resource, <:Real}`** are the input `Resource`s with conversion value `Real`.\n
- **`output::Dict{<:Resource, <:Real}`** are the generated `Resource`s with conversion value `Real`.\n
- **`data::Vector{Data}`** is the additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.
"""

struct HydroGenerator <: EMB.NetworkNode # plant or pump or both? 
    id::Any
    #power_cap::TimeProfile # maximum production MW/(time unit)
    cap::TimeProfile # maximum discharge mm3/(time unit)
    pq_curve::Union{Dict{<:Resource, <:Vector{<:Real}}, Nothing}# Production and discharge ratio [MW / m3/s]
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
    η::Vector{Real} # PQ_curve: production and discharge ratio [MW / m3/s]
    data::Vector{Data}
end
function HydroGenerator(
    id::Any,
    #power_cap::TimeProfile,
    cap::TimeProfile,
    #pq_curve::Dict{<:Real, <:Real},
    #pump_power_cap::TimeProfile,
    #pump_disch_cap::TimeProfile,
    #pump_pq_curve::Dict{<:Real, <:Real},
    #prod_min::TimeProfile,
    #prod_max::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real};
    pq_curve = nothing,
    η = Real[],
)

    return HydroGenerator(id, cap, pq_curve, opex_var, opex_fixed, input, output, η, Data[])
end

""" A Hydro Gate, modelled as a `NetworkNode` node. Can be used to model outlets/inlets and \
minimum/maximum requirements for water flow. 

## Fields
- **`id`** is the name/identifier of the node.\n
- **`cap::TimeProfile`** is the installed discharge capacity.\n
- **`opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`input::Dict{<:Resource, <:Real}`** are the input `Resource`s with conversion value `Real`.\n
- **`output::Dict{<:Resource, <:Real}`** are the generated `Resource`s with conversion value `Real`.\n
- **`data::Vector{Data}`** is the additional data (e.g. for investments). The field \
`data` is conditional through usage of a constructor.
"""
#TODO add option for maximum and minimum requirement

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

# Not needed?
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
    level_min(n::HydroReservoir, t)

Returns the minimum level of a node `n` of type `HydroReservoir` at operational period `t`
"""
level_min(n::HydroReservoir, t) = n.level_min[t]

"""
    pq_curve(n::HydroGenerator)

Returns the resources in the PQ-curve of a node `n` of type `HydroGenerator` 
"""
function pq_curve(n::HydroGenerator)
    if !isnothing(n.pq_curve)
        return collect(keys(n.pq_curve))
    else
        return nothing
    end
end

"""
    pq_curve(n::HydroGenerator, p)

Returns the values in the pq_curve for resurce p of a node `n` of type `HydroGenerator` 
"""

function pq_curve(n::HydroGenerator, p::Resource) 
    
    if !isnothing(n.pq_curve)
        return  n.pq_curve[p]
    else
        return nothing
    end

end
"""
    efficiency(n::HydroGenerator)

Returns vector of the efficiency segments a node `n` of type `HydroGenerator` 
"""
efficiency(n::HydroGenerator) = n.η