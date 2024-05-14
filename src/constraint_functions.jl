#! format: off

"""
    constraints_capacity(m, n::NonDisRES, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the maximum capacity of a `NonDisRES`.
Also sets the constraint defining curtailment.
"""
function EMB.constraints_capacity(m, n::NonDisRES, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] ≤ m[:cap_inst][n, t]
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
    constraints_flow_in(m, n::HydroStor, 𝒯::TimeStructure, modeltype::EnergyModel)

When `n::HydroStor`, the variable `:flow_in` is fixed to 0 for all potential inputs.
"""
function EMB.constraints_flow_in(m, n::HydroStor, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒫ⁱⁿ  = inputs(n)

    # Fix the inlet flow to a value of 0
    for t ∈ 𝒯
        fix(m[:stor_charge_use][n, t], 0; force=true)
        for p ∈ 𝒫ⁱⁿ
            fix(m[:flow_in][n, t, p], 0; force=true)
        end
    end
end

"""
    constraints_flow_in(m, n::PumpedHydroStor, 𝒯::TimeStructure, modeltype::EnergyModel)

When `n::PumpedHydroStor`, the variable `:flow_in` is multiplied with the `inputs` value
to calculate the variable `:stor_charge_use`.
"""
function EMB.constraints_flow_in(m, n::PumpedHydroStor, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒫ⁱⁿ  = inputs(n)

    # Constraint for the individual input stream connections
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ],
        m[:flow_in][n, t, p] * inputs(n, p) == m[:stor_charge_use][n, t]
    )
end

"""
    EMB.constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫, modeltype)

Function for creating the Δ constraint for the level of a `HydroStorage` node as well as
the specification of the initial level in a strategic period.

The change in storage level in the reservoir at operational periods `t` is the inflow through
`:level_inflow` plus the input `:stor_charge_use` minus the production `:stor_discharge_use`
and the spillage of water due to overflow `:hydro_spill`.
"""
function EMB.constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EnergyModel)
    # Declaration of the required subsets
    p_stor = storage_resource(n)

    # Constraint for the change in the level in a given operational period
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] ==
            level_inflow(n, t) + m[:stor_charge_use][n, t] -
            m[:stor_discharge_use][n, t] - m[:hydro_spill][n, t]
    )

    # The initial storage level is given by the specified initial level in the strategic
    # period `t_inv`. This level corresponds to the value before inflow and outflow.
    # This is different to the `RefStorage` node.
    @constraint(m, [t_inv ∈ strategic_periods(𝒯)],
        m[:stor_level][n, first(t_inv)] ==
            level_init(n, first(t_inv)) +
            m[:stor_level_Δ_op][n, first(t_inv)] * duration(first(t_inv))
    )

    # The minimum contents of the reservoir is bounded below. Not allowed
    # to drain it completely.
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] ≥ level_min(n, t) * m[:stor_level_inst][n, t]
    )
end

#! format: on



"""
    constraints_capacity(m, n::Inflow, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the maximum capacity of a `Inflow`.

"""
function EMB.constraints_capacity(m, n::Inflow, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t]
    )

    # Non dispatchable renewable energy sources operate at their max
    # capacity with repsect to the current profile (e.g. wind) at every time.
    @constraint(
        m,
        [t ∈ 𝒯],
        m[:cap_use][n, t] == profile(n, t)
    )

    constraints_capacity_installed(m, n, 𝒯, modeltype)
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
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] ==
           inputs(n, p_stor) * m[:flow_in][n, t, p_stor] -
           outputs(n, p_stor) * m[:flow_out][n, t, p_stor]
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
