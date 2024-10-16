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

"""
    build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::AbstractMinMaxConstraint, 𝒯)

Create minimum/maximum volume constraints for the `HydroReservoir` node. The
restriction is specified as a composite type of the abstract type `AbstractMinMaxConstraint`.
Penalty variables are included unless penalty value is not set or `Inf``.
"""
function build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::MinConstraint, 𝒯)
    for t ∈ 𝒯
        if is_active(c, t)
            if has_penalty(c, t)
                @constraint(m, m[:stor_level][n, t] + m[:rsv_vol_penalty_up][n, t] ≥
                    EMB.capacity(EMB.level(n), t) * value(c, t))
            else
                @constraint(m, m[:stor_level][n, t] ≥ EMB.capacity(EMB.level(n), t) * value(c, t))
            end
        end
    end
end
function build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::MaxConstraint, 𝒯)
    for t ∈ 𝒯
        if is_active(c, t)
            if has_penalty(c, t)
                @constraint(m, m[:stor_level][n, t] - m[:rsv_vol_penalty_down][n, t] ≤
                    EMB.capacity(EMB.level(n), t) * value(c, t))
            else
                @constraint(m, m[:stor_level][n, t] ≤ EMB.capacity(EMB.level(n), t) * value(c, t))
            end
        end
    end
end
function build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::ScheduleConstraint, 𝒯)
    for t ∈ 𝒯
        if is_active(c, t)
            if has_penalty(c, t)
                @constraint(m, m[:stor_level][n, t] +
                    m[:penalty_up][n, t] - m[:rsv_vol_penalty_down][n, t] ==
                    EMB.capacity(EMB.level(n), t) * value(c, t))
            else
                JuMP.fix(m[:stor_level][n, t], EMB.capacity(EMB.level(n), t) * value(c, t))
            end
        end
    end
end


"""
EMB.constraints_level_aux(m, n::HydroReservoir, 𝒯, 𝒫, modeltype::EnergyModel)

Create the Δ constraint for the level of the `HydroReservoir` node as well as the
specificaiton of the initial level in a strategic period.

The change in storage level in the reservoir at operational periods `t` is the flow into
the reservoir through the input `flow_in` and inflow minus the flow out of the reservoir
through the output `flow_out`.
"""
function EMB.constraints_level_aux(m, n::HydroReservoir{T} where T<:EMB.StorageBehavior,
    𝒯, 𝒫, modeltype::EnergyModel)
    # Declaration of the required subsets
    p_stor = storage_resource(n)

    # Constraint for the change in the level in a given operational period
    @constraint(
        m, [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] ==
            n.vol_inflow[t] +
            m[:stor_charge_use][n, t] - m[:stor_discharge_use][n, t]
    )

    # The minimum and maximum contents of the reservoir is bounded below and above.
    constraint_data = filter(is_constraint_data, node_data(n))
    for c in constraint_data
        build_hydro_reservoir_vol_constraints(m, n, c, 𝒯)
    end
end

"""
EMB.constraints_opex_var(m, n::HydroGate, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `HydroGate`.
This function relates the penalty costs for violating constraints to the objective.
"""
function EMB.constraints_opex_var(m, n::HydroGate, 𝒯ᴵⁿᵛ,
    modeltype::EnergyModel)

    constraints = filter(is_constraint_data, node_data(n))
    constraints_up = filter(has_penalty_up, constraints) # Max and schedule
    constraints_down = filter(has_penalty_down, constraints) # Min and schedule

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] ==
        sum(
            sum(
                m[:penalty_up][n, t] * penalty(c, t)
                for c in constraints_up if has_penalty(c, t)
            ) +
            sum(
                m[:penalty_down][n, t] * penalty(c, t)
                for c in constraints_down if has_penalty(c, t)
            )
        * multiple(t_inv, t) for t in t_inv)
    )
end

"""
EMB.constraints_opex_var(m, n::HydroResevoir{T}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `HydroReservoir`.
This function relates the penalty costs for violating constraints to the objective in
addition to exisitng OPEX for `Storage`.
"""
function EMB.constraints_opex_var(m, n::HydroReservoir{T}, 𝒯ᴵⁿᵛ,
    modeltype::EnergyModel) where {T <: EMB.StorageBehavior}

    # Extracts the contribution from the individual components
    if EMB.has_level_OPEX_var(n)
        opex_var_level = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
            sum(
                m[:stor_level][n, t] * opex_var(level(n), t) * multiple(t_inv, t) for
                t ∈ t_inv
            )
        )
    else
        opex_var_level = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end
    if EMB.has_charge_OPEX_var(n)
        opex_var_charge = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
            sum(
                m[:stor_charge_use][n, t] * opex_var(charge(n), t) * multiple(t_inv, t)
                for t ∈ t_inv
            )
        )
    else
        opex_var_charge = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end
    if EMB.has_discharge_OPEX_var(n)
        opex_var_discharge = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
            sum(
                m[:stor_discharge_use][n, t] *
                opex_var(discharge(n), t) *
                multiple(t_inv, t) for t ∈ t_inv
            )
        )
    else
        opex_var_discharge = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end

    # Create the constraint penalty constraint
    constraints = filter(is_constraint_data, node_data(n))
    constraints_up = filter(has_penalty_up, constraints) # Max and schedule
    constraints_down = filter(has_penalty_down, constraints) # Min and schedule

    opex_penalty_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(
            sum(
                m[:rsv_vol_penalty_up][n, t] * penalty(c, t)
                for c in constraints_up if has_penalty(c, t)
            ) +
            sum(
                m[:rsv_vol_penalty_down][n, t] * penalty(c, t)
                for c in constraints_down if has_penalty(c, t)
            )
        * multiple(t_inv, t) for t in t_inv)
    )

    # Create the overall constraint
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == opex_var_level[t_inv] + opex_var_charge[t_inv] +
            opex_var_discharge[t_inv] + opex_penalty_var[t_inv]
    )
end

function build_hydro_gate_constraints(m, n::HydroGate, c::MinConstraint, 𝒯::TimeStructure,
    p::ResourceCarrier)
    for t ∈ 𝒯
        if is_active(c, t)
            if has_penalty(c, t)
                @constraint(m, m[:flow_out][n, t, p] + m[:penalty_up][n, t] ≥ value(c, t))
            else
                @constraint(m, m[:flow_out][n, t, p] ≥ value(c, t))
            end
        end
    end
end
function build_hydro_gate_constraints(m, n::HydroGate, c::MaxConstraint, 𝒯::TimeStructure,
    p::ResourceCarrier)
    for t ∈ 𝒯
        if is_active(c, t)
            if has_penalty(c, t)
                @constraint(m, m[:flow_out][n, t, p] - m[:penalty_down][n, t] ≤ value(c, t))
            else
                @constraint(m, m[:flow_out][n, t, p] ≤ value(c, t))
            end
        end
    end
end
function build_hydro_gate_constraints(m, n::HydroGate, c::ScheduleConstraint,
    𝒯::TimeStructure, p::ResourceCarrier)
    for t ∈ 𝒯
        if is_active(c, t)
            if has_penalty(c, t)
                @constraint(m, m[:flow_out][n, t, p] +
                    m[:penalty_up][n, t] - m[:penalty_down][n, t] == value(c, t))
            else
                JuMP.fix(m[:flow_out][n, t, p], value(c, t); force=true)
            end
        end
    end
end

"""
    constraints_flow_out(m, n::HydroGate, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the outlet flow from a `HydroGate`.
This function implements the schedule and min/max constraints if present.
"""
function EMB.constraints_flow_out(m, n::HydroGate, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets, excluding CO2, if specified
    𝒫ᵒᵘᵗ = EMB.res_not(outputs(n), co2_instance(modeltype))
    # HydroGate should always have only one input/output resource
    p = first(𝒫ᵒᵘᵗ)

    # Constraint for the individual output stream connections
    @constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, p] == m[:cap_use][n, t] * outputs(n, p))

    # If HydroGate has schedule data, fix the flow out variable
    constraints = filter(is_constraint_data, node_data(n))
    for c in constraints
        build_hydro_gate_constraints(m, n, c, 𝒯, p)
    end
end

"""
    constraints_flow_out(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the outlet flow from a HydroGenerator Node.
"""
function EMB.constraints_flow_out(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets, excluding CO2, if specified
    𝒫ᵒᵘᵗ = EMB.res_not(outputs(n), co2_instance(modeltype))
    𝒫ⁱⁿ  = EMB.res_not(inputs(n), co2_instance(modeltype))

    # Constraint for the individual output stream connections
    # produksjon = discharge*energy equivalent
    # NB: If PQ-curve is being used, the energy equivalent must be >= best efficiency
    # TODO: overwrite energy equivalent if PQ-curve given
    # TODO: update energy equivalent if only one value in PQ-curve


    new_resource = 𝒫ᵒᵘᵗ[𝒫ᵒᵘᵗ .∉ [𝒫ⁱⁿ]] # Power
    original_resource = 𝒫ᵒᵘᵗ[𝒫ᵒᵘᵗ .∈ [𝒫ⁱⁿ]] # Water
    # Since the type of resource is defined by the user it is not convenient to set conditions
    # based on the type (naming conventions or spelling can vary, e.g. water/hydro or power/electricity).

    @constraint(m, [t ∈ 𝒯, p ∈ original_resource],
    m[:flow_out][n, t, p] == m[:cap_use][n, t] * outputs(n, p)
)

    #TODO make cleaner as function
    #if !isnothing(pq_curve) & isnothing(η)
    #    η = calculate_efficiency()
    #end

    #@constraint(m, [t ∈ 𝒯, p ∈ new_resource],
    #m[:flow_out][n, t, p] <= m[:cap_use][n, t] * outputs(n, p)
    #)

    if !isnothing(pq_curve(n)) && length(original_resource) == 1 && length(new_resource) == 1
        disch_levels = pq_curve(n, original_resource[1])
        power_levels = pq_curve(n, new_resource[1])
        #n.η = Real[]
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
