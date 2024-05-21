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
    @constraint(m, [t ∈ 𝒯], m[:cap_use][n, t] <= m[:cap_inst][n, t])
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
    constraints_opex_var(m, n::HydroReservoir, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `HydroReservoir`.
"""
function EMB.constraints_opex_var(m, n::HydroReservoir, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    p_stor = EMB.storage_resource(n)
    @constraint(
        m,
        [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] ==
            -m[:stor_level][n, last(t_inv)] * opex_var(n, last(t_inv)) * EMB.multiple(t_inv, last(t_inv))
        )
end

"""
    constraints_flow_out(m, n::HydroStation, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the outlet flow from a generic `Node`.
This function serves as fallback option if no other function is specified for a `Node`.
"""

function constraints_flow_out(m, n::HydroStation, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets, excluding CO2, if specified
    𝒫ᵒᵘᵗ = EMB.res_not(outputs(n), co2_instance(modeltype))
    𝒫ⁱⁿ  = EMB.res_not(inputs(n), co2_instance(modeltype))

    # Constraint for the individual output stream connections
    # produksjon = discharge*energiekvivalent


    new_resource = 𝒫ᵒᵘᵗ[𝒫ᵒᵘᵗ .∉ [𝒫ⁱⁿ]]
    original_resource = 𝒫ᵒᵘᵗ[𝒫ᵒᵘᵗ .∈ [𝒫ⁱⁿ]]

    @constraint(m, [t ∈ 𝒯, p ∈ original_resource],
    m[:flow_out][n, t, p] == m[:cap_use][n, t] * outputs(n, p)
)

#@constraint(m, [t ∈ 𝒯, p ∈ new_resource],
#m[:flow_out][n, t, p] == m[:cap_use][n, t] * outputs(n, p)
#)

    if length(original_resource) == 1 && length(new_resource) == 1
        disch_levels = pq_curve(n, original_resource[1])
        power_levels = pq_curve(n, new_resource[1])
        if length(disch_levels) == length(power_levels) && length(disch_levels) > 1
            for i in range(2, length(disch_levels))
                push!(n.η, (power_levels[i] - power_levels[i-1]) / (disch_levels[i] - disch_levels[i-1]))
            end
        else println("incorrect pq_curve values")
        end
       println(n.η)
    else println("Requires one input resource and two output resources.")

    end

    # produksjon = discharge_segment*virkningsgrad_segment
    Nˢ = range(1,length(n.η))
    water_seq = pq_curve(n, original_resource[1])
    println(water_seq)

    @constraint(m, [t ∈ 𝒯, q ∈ Nˢ],
    m[:discharge_segment][n, t, q] <= water_seq[q+1]*m[:cap_inst][n, t] .- water_seq[q]*m[:cap_inst][n, t]
    )

    @constraint(m, [t ∈ 𝒯],
    m[:cap_use][n, t] == sum(m[:discharge_segment][n, t, q] for q ∈ Nˢ)
    )

    @constraint(m, [t ∈ 𝒯, p ∈ new_resource],
    m[:flow_out][n, t, p] == sum(m[:discharge_segment][n, t, q] * n.η[q] for q ∈ Nˢ)
)


    # Opprett variabel per segment




end
