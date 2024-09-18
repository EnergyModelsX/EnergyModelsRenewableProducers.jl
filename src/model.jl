
"""
    EMB.variables_node(m, 𝒩ⁿᵈʳ::Vector{NonDisRES}, 𝒯, modeltype::EnergyModel)

Create the optimization variable `:curtailment` for every NonDisRES node. This method is called
from `EnergyModelsBase.jl`."""
function EMB.variables_node(m, 𝒩ⁿᵈʳ::Vector{NonDisRES}, 𝒯, modeltype::EnergyModel)
    @variable(m, curtailment[𝒩ⁿᵈʳ, 𝒯] >= 0)
end

# NB: note that the create_node method that will run for a node n::NonDisRES, is the
# method defined for a general Source node, which is located in EnergyModelsBase.

"""
    EMB.variables_node(m, 𝒩::Vector{HydroStorage}, 𝒯, modeltype::EnergyModel)

Create the optimization variable `:hydro_spill` for every HydroStorage node. This variable
enables hydro storage nodes to spill water from the reservoir without producing energy.
Wihtout this slack variable, parameters with too much inflow would else lead to an
infeasible model. """
function EMB.variables_node(m, 𝒩::Vector{HydroStorage}, 𝒯, modeltype::EnergyModel)
    @variable(m, hydro_spill[𝒩, 𝒯] >= 0)
end

"""
    EMB.create_node(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EnergyModel)

Sets all constraints for the regulated hydro storage node.
"""


function EMB.create_node(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    p_stor = EMB.storage_resource(n)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # If the reservoir has no pump, the stored resource cannot flow in.
    if isa(n, HydroStor)
        @constraint(m, [t ∈ 𝒯], m[:flow_in][n, t, p_stor] == 0)
    end

    # Energy balance constraints for stored electricity.
    constraints_level(m, n, 𝒯, 𝒫, modeltype)

    # The flow_out is equal to the production stor_rate_use.
    @constraint(
        m,
        [t ∈ 𝒯],
        m[:flow_out][n, t, p_stor] == m[:stor_rate_use][n, t] * outputs(n, p_stor)
    )

    # Can not produce more energy than what is availbable in the reservoir.
    @constraint(m, [t ∈ 𝒯], m[:stor_rate_use][n, t] <= m[:stor_level][n, t])

    # The minimum contents of the reservoir is bounded below. Not allowed
    # to drain it completely.
    @constraint(
        m,
        [t ∈ 𝒯],
        m[:stor_level][n, t] ≥ level_min(n, t) * m[:stor_cap_inst][n, t]
    )

    # Iterate through all data and set up the constraints corresponding to the data
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

    # Call of the function for limiting the capacity to the maximum installed capacity
    constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end

"""
    EMB.variables_node(m, 𝒩::Vector{HydroGenerator}, 𝒯, modeltype::EnergyModel)

Create the optimization variable `:discharge_segment` for every HydroGenerator node. This variable
enables the use of a concave PQ-curve. The sum of the utilisation of the discharge_sements has to
equal the cap_use. """
function EMB.variables_node(m, 𝒩::Vector{HydroGenerator}, 𝒯, modeltype::EnergyModel)

    𝒫ᵒᵘᵗ = EMB.res_not(outputs(first(𝒩)), co2_instance(modeltype))
    𝒫ⁱⁿ  = EMB.res_not(inputs(first(𝒩)), co2_instance(modeltype))
    original_resource = 𝒫ᵒᵘᵗ[𝒫ᵒᵘᵗ .∈ [𝒫ⁱⁿ]]
    
    for n in 𝒩
        if !isnothing(pq_curve(n, original_resource[1]))
            @variable(m, discharge_segment[n, 𝒯, 1:length(pq_curve(n, original_resource[1]))-1] >= 0)
        end
    end
end

"""
    create_node(m, n::HydroGenerator, 𝒯, 𝒫, modeltype::EnergyModel)

Set all constraints for a `HydroGenerator`.

"""
function EMB.create_node(m, n::HydroGenerator, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Iterate through all data and set up the constraints corresponding to the data
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

    # Call of the function for the inlet flow to and outlet flow from the `NetworkNode` node
    constraints_flow_in(m, n, 𝒯, modeltype)
    constraints_flow_out(m, n, 𝒯, modeltype)

    # Call of the function for limiting the capacity to the maximum installed capacity
    constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end