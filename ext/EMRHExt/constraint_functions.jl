function EMB.constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EMRH.RecHorEnergyModel)

    # Constraint for the change in the level in a given operational period
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] ==
            EMRP.level_inflow(n, t) + m[:stor_charge_use][n, t] -
            m[:stor_discharge_use][n, t] - m[:hydro_spill][n, t]
    )

    # The minimum contents of the reservoir is bounded below. Not allowed
    # to drain it completely.
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] ≥ EMRP.level_min(n, t) * m[:stor_level_inst][n, t]
    )
end
