
""" 
    EMB.variables_node(m, 𝒩ⁿᵈʳ::Vector{NonDisRES}, 𝒯, modeltype::EnergyModel)

Create the optimization variable `:curtailment` for every NonDisRES node. This method is called
from `EnergyModelsBase.jl`."""
function EMB.variables_node(m, 𝒩ⁿᵈʳ::Vector{NonDisRES}, 𝒯, modeltype::EnergyModel)

    @variable(m, curtailment[𝒩ⁿᵈʳ, 𝒯] >= 0)
end


"""
    EMB.create_node(m, n::NonDisRES, 𝒯, 𝒫, modeltype::EnergyModel)

Sets all constraints for a non-dispatchable renewable energy source.
"""
function EMB.create_node(m, n::NonDisRES, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    𝒫ᵉᵐ = EMB.res_sub(𝒫, EMB.ResourceEmit)
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)

    # Non dispatchable renewable energy sources operate at their max
    # capacity with repsect to the current profile (e.g. wind) at every time.
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] + m[:curtailment][n, t] == n.Profile[t] * m[:cap_inst][n, t])

    # Constraint for the emissions to avoid problems with unconstrained variables.
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ], m[:emissions_node][n, t, p_em] == 0)
        
    # Call of the function for the outlet flow from the `Source` node
    EMB.constraints_flow_out(m, n, 𝒯)

    # Call of the function for limiting the capacity to the maximum installed capacity
    EMB.constraints_capacity(m, n, 𝒯)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    EMB.constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ)
    EMB.constraints_opex_var(m, n, 𝒯ᴵⁿᵛ)

end


"""
    EMB.create_node(m, n::RegHydroStor, 𝒯, 𝒫, modeltype::EnergyModel)

Sets all constraints for the regulated hydro storage node.
"""
function EMB.create_node(m, n::RegHydroStor, 𝒯, 𝒫, modeltype::EnergyModel)
    
    # Declaration of the required subsets.
    p_stor = n.Stor_res
    𝒫ᵉᵐ   = EMB.res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ  = strategic_periods(𝒯)

    # If the reservoir has no pump, the stored resource cannot flow in.
    if ! n.Has_pump
        @constraint(m, [t ∈ 𝒯], m[:flow_in][n, t, p_stor] == 0)
    end

    # The storage level in the reservoir at operational time t, is the stor_level
    # of the previous operation period plus the inflow of period t minus the production
    # (stor_rate_use) of period t. For the first operational period in an investment period, 
    # stor_level is the initial reservoir level, plus inflow, minus the production in that period.
    for t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ t_inv
        if t == first_operational(t_inv)
            @constraint(m, 
                m[:stor_level][n, t] ==  n.Level_init[t]
                            + (n.Level_inflow[t] + n.Input[p_stor] * m[:flow_in][n, t , p_stor] 
                            - m[:stor_rate_use][n, t])
                            * t.duration)
        else
            @constraint(m, 
                m[:stor_level][n, t] ==  m[:stor_level][n, previous(t, 𝒯)]
                            + (n.Level_inflow[t] + n.Input[p_stor] * m[:flow_in][n, t, p_stor]
                            - m[:stor_rate_use][n, t])
                            * t.duration)
        end
    end

    # The flow_out is equal to the production stor_rate_use.
    @constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, p_stor] == m[:stor_rate_use][n, t] * n.Output[p_stor])

    # Can not produce more energy than what is availbable in the reservoir.
    @constraint(m, [t ∈ 𝒯], m[:stor_rate_use][n, t] <= m[:stor_level][n, t])
    
    # The minimum contents of the reservoir is bounded below. Not allowed 
    # to drain it completely.
    @constraint(m, [t ∈ 𝒯], m[:stor_level][n, t] >= n.Level_min[t] * m[:stor_cap_inst][n, t])

    # Constraint for the emissions to avoid problems with unconstrained variables.
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ], m[:emissions_node][n, t, p_em] == 0)
        
    # Call of the function for limiting the capacity to the maximum installed capacity
    EMB.constraints_capacity(m, n, 𝒯)
    
    # Call of the functions for both fixed and variable OPEX constraints introduction
    EMB.constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ)
    EMB.constraints_opex_var(m, n, 𝒯ᴵⁿᵛ)

end
