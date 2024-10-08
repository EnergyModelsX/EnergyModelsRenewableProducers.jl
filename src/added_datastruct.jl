


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
