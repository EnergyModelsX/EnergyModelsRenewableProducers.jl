" Constraints for a non-dispatchable renewable energy source."
function EMB.create_node(m, n::NonDisRES, 𝒯, 𝒫)
    # Declaration of the required subsets.
    𝒫ᵒᵘᵗ = keys(n.output)
    𝒫ᵉᵐ = EMB.res_sub(𝒫, EMB.ResourceEmit)
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)
 
    # Non dispatchable renewable energy sources operate at their max
    # capacity with repsect to the current profile (e.g. wind) at every time.
    @constraint(m, [t ∈ 𝒯],
        m[:cap_usage][n, t] == n.profile[t] * m[:cap_max][n, t])


    # Constraints identical to other Source nodes.

    # Constraint for the individual stream connections.
    for p ∈ 𝒫ᵒᵘᵗ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_out][n, t, p] == m[:cap_usage][n, t] * n.output[p])
    end

    @constraint(m, [t ∈ 𝒯], 
        m[:cap_usage][n, t] <= m[:cap_max][n, t])

    # Constraint for the emissions associated to energy sources from construction.
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == m[:cap_usage][n, t]*n.emissions[p_em])

    # Constraint for the Opex contributions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_usage][n, t]*n.var_opex[t] for t ∈ t_inv))

end


# function prepare_node(m, n::RegHydroStor, 𝒯, 𝒫)
function EMB.create_node(m, n::RegHydroStor, 𝒯, 𝒫)
    # The resource (there should be only one) in n.output is stored. The resources in n.input are
    # either stored, or used by the storage.
    p_stor = [k for (k, v) ∈ n.output if v == 1][1]
    𝒫ᵉᵐ   = EMB.res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ  = strategic_periods(𝒯)

    # If the reservoir has no pump, the stored resource cannot flow in.
    if ! n.has_pump
        @constraint(m, [t ∈ 𝒯], m[:flow_in][n, t, p_stor] == 0)
    end

    # The storage level in the reservoir at operational time t, is the stor_level
    # of the previous operation period plus the inflow of period t minus the production
    # (cap_usage) of period t. For the first operational period in an investment period, 
    # stor_level is the initial reservoir level, plus inflow, minus the production in that period.
    for t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ t_inv
        if t == first_operational(t_inv)
            @constraint(m, 
                m[:stor_level][n, t] ==  n.init_reservoir[t]
                            + n.inflow[t] + n.input[p_stor] * m[:flow_in][n, t , p_stor] 
                            - m[:flow_out][n, t , p_stor])
        else
            @constraint(m, 
                m[:stor_level][n, t] ==  m[:stor_level][n, previous(t)]
                            + n.inflow[t] + n.input[p_stor] * m[:flow_in][n, t, p_stor]
                            - m[:flow_out][n, t , p_stor])
        end
    end

    # The flow_out is equal to the production cap_usage.
    @constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, p_stor] == m[:cap_usage][n, t])

    # The storage level at every time must be less than the installed storage capacity.
    # TODO it should be pssible to invest in stor_max, this might have to be moved.
    @constraint(m, [t ∈ 𝒯], m[:stor_level][n, t] <= m[:stor_max][n, t])
    
    # Can not produce more energy than what is availbable in the reservoir.
    @constraint(m, [t ∈ 𝒯], m[:cap_usage][n, t] <= m[:stor_level][n, t])
    
    # The minimum contents of the reservoir is bounded below. Not allowed 
    # to drain it completely.
    @constraint(m, [t ∈ 𝒯], m[:stor_level][n, t] >= n.min_level[t] * m[:stor_max][n, t])

    # Assuming no investments, the production at every operational
    # period is bounded by the installed capacity.
    # TODO this inequality should probably be moved to the first method in
    # energymodelsbase/model.jl, to make sure it is compatible with the 
    # investment package. This need to be done for other nodes too.
    @constraint(m, [t ∈ 𝒯], m[:cap_usage][n, t] <= m[:cap_max][n, t])

    # Constraints identical to other Source nodes.
    𝒫ᵒᵘᵗ = keys(n.output)
    𝒫ᵉᵐ = EMB.res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraint for the emissions associated to energy sources from construction.
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == m[:cap_usage][n, t]*n.emissions[p_em])

    # Constraint for the Opex contributions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_usage][n, t]*n.var_opex[t] for t ∈ t_inv))

end
