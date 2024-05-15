#! format: off

"""
    constraints_capacity(m, n::NonDisRES, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the maximum capacity of a `NonDisRES`.
Also sets the constraint defining curtailment.
"""
function EMB.constraints_capacity(m, n::NonDisRES, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t]
    )

    # Non dispatchable renewable energy sources operate at their max
    # capacity with repsect to the current profile (e.g. wind) at every time.
    @constraint(
        m,
        [t ∈ 𝒯],
        m[:cap_use][n, t] + m[:curtailment][n, t] == profile(n, t) * m[:cap_inst][n, t]
    )

    constraints_capacity_installed(m, n, 𝒯, modeltype)
end


"""
    EMB.constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫, modeltype)

Function for creating the Δ constraint for the level of a `HydroStorage` node as well as
the specificaiton of the initial level in a strategic period.

The change in storage level in the reservoir at operational periods `t` is the inflow through
`level_inflow` plus the input `flow_in` minus the production `stor_rate_use` and the
spillage of water due to overflow `hydro_spill`.
"""
function EMB.constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫, modeltype)
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
    EMB.constraints_level_sp(
        m,
        n::HydroStorage,
        t_inv::TS.StrategicPeriod{T, U},
        𝒫,
        modeltype
        ) where {T, U<:SimpleTimes}

Function for creating the level constraint for a `HydroStorage` node when the
TimeStructure is given as `SimpleTimes`.
"""
function EMB.constraints_level_sp(
    m,
    n::HydroStorage,
    t_inv::TS.StrategicPeriod{T, U},
    𝒫,
    modeltype
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
    EMB.constraints_level_sp(
        m,
        n::HydroStorage,
        t_inv::TS.StrategicPeriod{T, RepresentativePeriods{U, T, SimpleTimes{T}}},
        𝒫,
        modeltype
        ) where {T, U}

Function for creating the level constraint for a `HydroStorage` storage node when the
operational `TimeStructure` is given as `RepresentativePeriods`.
"""
function EMB.constraints_level_sp(
    m,
    n::HydroStorage,
    t_inv::TS.StrategicPeriod{T, RepresentativePeriods{U, T, SimpleTimes{T}}},
    𝒫,
    modeltype
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

"""
    constraints_capacity(m, n::Inflow, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the maximum capacity of a `Inflow`.

"""
function EMB.constraints_capacity(m, n::Inflow, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯], m[:cap_use][n, t] <= m[:cap_inst][n, t])

    # Non dispatchable renewable energy sources operate at their max
    # capacity with repsect to the current profile (e.g. wind) at every time.
    @constraint(m, [t ∈ 𝒯], m[:cap_use][n, t] == profile(n, t))

    return constraints_capacity_installed(m, n, 𝒯, modeltype)
end

#   Level constraints for new 'Storage' type:

"""
EMB.constraints_level_aux(m, n::HydroReservoir, 𝒯, 𝒫, modeltype)

Function for creating the Δ constraint for the level of a `HydroReservoir` node as well as
the specificaiton of the initial level in a strategic period.

The change in storage level in the reservoir at operational periods `t` is the flow into the reservoir through
the input `flow_in` minus the flow out of the reservoir through the output `flow_out`.
"""
function EMB.constraints_level_aux(m, n::HydroReservoir, 𝒯, 𝒫, modeltype)
    # Declaration of the required subsets
    p_stor = storage_resource(n)

    # Constraint for the change in the level in a given operational period
    @constraint(
        m,
        [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] ==
            inputs(n, p_stor) * m[:flow_in][n, t, p_stor] -
        outputs(n, p_stor) * m[:flow_out][n, t, p_stor]
    )

    # The initial storage level is given by the specified initial level in the strategic
    # period `t_inv`. This level corresponds to the value before inflow and outflow.
    # This is different to the `RefStorage` node.
    @constraint(
        m,
        [t_inv ∈ strategic_periods(𝒯)],
        m[:stor_level][n, first(t_inv)] ==
            level_init(n, first(t_inv)) +
        m[:stor_level_Δ_op][n, first(t_inv)] * duration(first(t_inv))
    )
end

"""
    EMB.constraints_level_sp(
        m,
        n::HydroReservoir,
        t_inv::TS.StrategicPeriod{T, U},
        𝒫,
        modeltype
        ) where {T, U<:SimpleTimes}

Function for creating the level constraint for a `HydroReservoir` node when the
TimeStructure is given as `SimpleTimes`.
"""
function EMB.constraints_level_sp(
    m, n::HydroReservoir, t_inv::TS.StrategicPeriod{T,U}, 𝒫, modeltype
) where {T,U<:SimpleTimes}

    # Water balance constraints for the hydro reservoir.
    for (t_prev, t) ∈ withprev(t_inv)
        if isnothing(t_prev) # Binds resevoir filling in first period to last period. 
            @constraint(
                m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, last(t_inv)] + m[:stor_level_Δ_op][n, t] * duration(t)
            )
        else
            @constraint(
                m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, t_prev] + m[:stor_level_Δ_op][n, t] * duration(t)
            )
        end
    end
end
