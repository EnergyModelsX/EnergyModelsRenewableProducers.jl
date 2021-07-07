" Constraints for a non-dispatchable renewable energy source.
"
function EMB.create_node(m, n::NonDispatchableRenewableEnergy, 𝒯, 𝒫)
    # Declaration of the required subsets.
    𝒫ᵒᵘᵗ = keys(n.output)
    𝒫ᵉᵐ = EMB.res_sub(𝒫, EMB.ResourceEmit)
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)

    # Constraint for the individual stream connections.
    for p ∈ 𝒫ᵒᵘᵗ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_out][n, t, p] == m[:cap_usage][n, t] * n.output[p])
    end
    
    # Non dispatchable renewable energy sources operate at their max
    # capacity with repsect to the current profile (e.g. wind) at every time.
    @constraint(m, [t ∈ 𝒯],
        m[:cap_usage][n, t] == n.profile[t] * m[:cap_max][n, t])

    # Constraint for the emissions associated to energy sources from construction.
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == m[:cap_usage][n, t]*n.emissions[p_em])

    # Constraint for the Opex contributions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_usage][n, t]*n.var_opex[t] for t ∈ t_inv))

end
