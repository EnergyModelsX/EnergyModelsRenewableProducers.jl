#! format: off
"""
    EMB.constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫)

Function for creating the Δ constraint for the level of a `HydroStorage` node.

The change storage level in the reservoir at operational periods `t` is the inflow through
`level_inflow` plus the input `flow_in` minus the production `stor_rate_use` and the
spillage of water due to overflow `hydro_spill`.
"""
function EMB.constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫)
    # Declaration of the required subsets
    p_stor = storage_resource(n)

    # Constraint for the change in the level in a given operational period
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] ==
            level_inflow(n, t) + inputs(n, p_stor) * m[:flow_in][n, t, p_stor] -
            m[:stor_rate_use][n, t] - m[:hydro_spill][n, t]
    )

    # The initial storage level is given by the specified initial level in the strategic
    # period `t_inv`. This level corresponds to the value before inflow and outflow.
    # This is different to the `RefStorage` node.
    @constraint(m, [t_inv ∈ strategic_periods(𝒯)],
        m[:stor_level][n, first(t_inv)] ==
            level_init(n, first(t_inv)) +
            m[:stor_level_Δ_op][n, first(t_inv)] * duration(first(t_inv))
    )
end

"""
    EMB.constraints_level(
        m,
        n::HydroStorage,
        t_inv::TS.StrategicPeriod{T, U},
        𝒫
        ) where {T, U<:SimpleTimes}

Function for creating the level constraint for a `HydroStorage` node when the
TimeStructure is given as `SimpleTimes`.
"""
function EMB.constraints_level(
    m,
    n::HydroStorage,
    t_inv::TS.StrategicPeriod{T, U},
    𝒫
    ) where {T, U<:SimpleTimes}

    # Energy balance constraints for stored hydro power.
    for (t_prev, t) ∈ withprev(t_inv)
        if isnothing(t_prev)
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, last(t_inv)] +
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )
        else
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, t_prev] +
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )
        end
    end
end

"""
    EMB.constraints_level(
        m,
        n::HydroStorage,
        t_inv::TS.StrategicPeriod{T, RepresentativePeriods{U, T, SimpleTimes{T}}},
        𝒫
        ) where {S<:ResourceCarrier, T, U}

Function for creating the level constraint for a reference storage node with a
`ResourceCarrier` resource when the TimeStructure is given as StrategicPeriod.
"""
function EMB.constraints_level(
    m,
    n::HydroStorage,
    t_inv::TS.StrategicPeriod{T, RepresentativePeriods{U, T, SimpleTimes{T}}},
    𝒫
    ) where {T, U}

    # Declaration of the required subsets
    𝒯ʳᵖ = repr_periods(t_inv)

    # Constraint for the total change in the level in a given representative period
    @constraint(m, [t_rp ∈ 𝒯ʳᵖ],
        m[:stor_level_Δ_rp][n, t_rp] ==
            sum(m[:stor_level_Δ_op][n, t] * multiple_strat(t_inv, t) * duration(t) for t ∈ t_rp)
    )

    # Constraint that the total change has to be 0
    @constraint(m, sum(m[:stor_level_Δ_rp][n, t_rp] for t_rp ∈ 𝒯ʳᵖ) == 0)

    # Mass/energy balance constraints for stored energy carrier.
    for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ), (t_prev, t) ∈ withprev(t_rp)
        if isnothing(t_rp_prev) && isnothing(t_prev)

            # Last representative period in t_inv
            t_rp_last = last(𝒯ʳᵖ)

            # Constraint for the level of the first operational period in the first
            # representative period in a strategic period
            # The substraction of stor_level_Δ_op[n, first(t_rp_last)] is necessary to avoid
            # treating the first operational period differently with respect to the level
            # as the latter is at the end of the period
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, first(t_rp_last)] -
                    m[:stor_level_Δ_op][n, first(t_rp_last)] * duration(first(t_rp_last)) +
                    m[:stor_level_Δ_rp][n, t_rp_last] +
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )

            # Constraint to avoid starting below 0 in this operational period
            @constraint(m,
                m[:stor_level][n, t] -
                m[:stor_level_Δ_op][n, t] * duration(t) ≥ 0
            )

            # Constraint to avoid having a level larger than the storage allows
            @constraint(m,
                m[:stor_level][n, t] -
                m[:stor_level_Δ_op][n, t] * duration(t) ≤ m[:stor_cap_inst][n, t]
            )

        elseif isnothing(t_prev)
            # Constraint for the level of the first operational period in any following
            # representative period
            # The substraction of stor_level_Δ_op[n, first(t_rp_prev)] is necessary to avoid
            # treating the first operational period differently with respect to the level
            # as the latter is at the end of the period
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, first(t_rp_prev)] -
                    m[:stor_level_Δ_op][n, first(t_rp_prev)] * duration(first(t_rp_prev)) +
                    m[:stor_level_Δ_rp][n, t_rp_prev] +
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )

            # Constraint to avoid starting below 0 in this operational period
            @constraint(m,
                m[:stor_level][n, t] - m[:stor_level_Δ_op][n, t] * duration(t) ≥
                    level_min(n, t) * m[:stor_cap_inst][n, t]
            )
            # Constraint to avoid having a level larger than the storage allows
            @constraint(m,
                m[:stor_level][n, t] - m[:stor_level_Δ_op][n, t] * duration(t) ≤
                    m[:stor_cap_inst][n, t]
            )
        else
            # Constraint for the level of a standard operational period
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, t_prev] +
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )
        end
    end
end

#! format: on
"""
    constraints_opex_var(m, n::HydroStor, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `HydroStor`.
"""
function EMB.constraints_opex_var(m, n::HydroStor, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    p_stor = EMB.storage_resource(n)
    @constraint(
        m,
        [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(
            m[:flow_out][n, t, p_stor] * opex_var(n, t) * EMB.multiple(t_inv, t) for
            t ∈ t_inv
        )
    )
end

"""
    constraints_opex_var(m, n::PumpedHydroStor, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `PumpedHydroStor`.
"""
function EMB.constraints_opex_var(m, n::PumpedHydroStor, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    p_stor = EMB.storage_resource(n)
    @constraint(
        m,
        [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(
            (
                m[:flow_in][n, t, p_stor] * opex_var_pump(n, t) +
                m[:flow_out][n, t, p_stor] * opex_var(n, t)
            ) * EMB.multiple(t_inv, t) for t ∈ t_inv
        )
    )
end
