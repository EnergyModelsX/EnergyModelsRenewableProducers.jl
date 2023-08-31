
"""
    constraints_opex_var(m, n::HydroStor, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `HydroStor`.
"""
function EMB.constraints_opex_var(m, n::HydroStor, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    @constraint(
        m,
        [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] ==
        sum(m[:flow_out][n, t, n.Stor_res] * n.Opex_var[t] * duration(t) for t ∈ t_inv)
    )
end

"""
    constraints_opex_var(m, n::PumpedHydroStor, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `PumpedHydroStor`.
"""
function EMB.constraints_opex_var(m, n::PumpedHydroStor, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    @constraint(
        m,
        [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(
            (
                m[:flow_in][n, t, n.Stor_res] * n.Opex_var_pump[t] +
                m[:flow_out][n, t, n.Stor_res] * n.Opex_var[t]
            ) * duration(t) for t ∈ t_inv
        )
    )
end
