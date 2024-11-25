function RMP.multiplication_variables(
    m,
    n::AbstractBattery,
    𝒯ᴵⁿᵛ,
    modeltype::AbstractInvestmentModel
)
    if EMI.has_investment(n, :level)
        var_b = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:bat_stack_replacement_b][n, t_inv])
        var_cont = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:stor_level_current][n, t_inv])

        # Calculate linear reformulation of the multiplication of
        # `stor_level_current * bat_stack_replacement_b`.
        # This is achieved through the introduction of an auxiliary variable
        #   `prod` = `stor_level_current * bat_stack_replacement_b`
        cap_lower_bound = FixedProfile(0)
        cap_upper_bound = EMI.max_installed(EMI.investment_data(n, :level))
        prod = EMH.linear_reformulation(
            m,
            𝒯ᴵⁿᵛ,
            var_b,
            var_cont,
            cap_lower_bound,
            cap_upper_bound,
        )
    else
        # Calculation of the multiplication with the installed capacity of the node
        prod = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
            capacity(level(n), t_inv) * [:bat_stack_replacement_b][n, t_inv]
        )
    end
    return prod
end

function capacity_max(n::AbstractBattery, t_inv, modeltype::AbstractInvestmentModel)
    if EMI.has_investment(n, :level)
        max_installed = capacity(level(n), t_inv) * cycles(n)
    else
        max_installed = EMI.max_installed(EMI.investment_data(n, :level)) * cycles(n)
    end
    return max_installed
end
