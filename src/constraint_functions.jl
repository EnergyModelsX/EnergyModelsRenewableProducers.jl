#! format: off

"""
    constraints_capacity(m, n::AbstractNonDisRES, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the maximum capacity of a `AbstractNonDisRES`.
Also sets the constraint defining curtailment.
"""
function EMB.constraints_capacity(m, n::AbstractNonDisRES, 𝒯::TimeStructure, modeltype::EnergyModel)
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
    build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::Constraint, 𝒯)

Create minimum/maximum/schedule volume constraints for the `HydroReservoir` node. The
`Constraint{T}` can have types `T <: AbstractConstraintType` that defines the direction of
the constraint.
Penalty variables are included unless penalty value is not set or `Inf``.
"""
function build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::Constraint{MinConstraintType}, 𝒯)
    p = storage_resource(n)
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & has_penalty(c, t)],
        m[:stor_level][n, t] + m[:rsv_penalty_up][n, t, p] ≥ EMB.capacity(EMB.level(n), t) * value(c, t))
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & !has_penalty(c, t)],
        m[:stor_level][n, t] ≥ EMB.capacity(EMB.level(n), t) * value(c, t))
end
function build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::Constraint{MaxConstraintType}, 𝒯)
    p = storage_resource(n)
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & has_penalty(c, t)],
        m[:stor_level][n, t] - m[:rsv_penalty_down][n, t, p] ≤ EMB.capacity(EMB.level(n), t) * value(c, t))
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & !has_penalty(c, t)],
        m[:stor_level][n, t] ≤ EMB.capacity(EMB.level(n), t) * value(c, t))
end
function build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::Constraint{ScheduleConstraintType}, 𝒯)
    p = storage_resource(n)
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & has_penalty(c, t)],
        m[:stor_level][n, t] + m[:rsv_penalty_up][n, t, p] - m[:rsv_penalty_down][n, t, p] ==
        EMB.capacity(EMB.level(n), t) * value(c, t))
    for t ∈ 𝒯
        if is_active(c, t) & !has_penalty(c, t)
            JuMP.fix(m[:stor_level][n, t], EMB.capacity(EMB.level(n), t) * value(c, t))
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

    # Constraint for the change in the level in a given operational period
    @constraint(
        m, [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] ==
            n.vol_inflow[t] +
            m[:stor_charge_use][n, t] - m[:stor_discharge_use][n, t]
    )

    # The minimum and maximum contents of the reservoir is bounded below and above.
    for c in constraint_data(n)
        build_hydro_reservoir_vol_constraints(m, n, c, 𝒯)
    end
end

"""
EMB.constraints_opex_var(m, n::HydroGate, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `HydroGate`.
This function relates the penalty costs for violating constraints to the objective.
"""
function EMB.constraints_opex_var(m, n::HydroGate, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

    constraints = constraint_data(n)
    constraints_up = filter(has_penalty_up, constraints) # Max and schedule
    constraints_down = filter(has_penalty_down, constraints) # Min and schedule

    opex_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], sum(m[:cap_use][n, t] * EMB.opex_var(n, t) *
        scale_op_sp(t_inv, t) for t ∈ t_inv))

    p = first(inputs(n))
    if length(constraints_up) > 0
        c_up = first(constraints_up)
        penalty_up_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], sum(m[:gate_penalty_up][n, t, p] *
            penalty(c_up, t) * scale_op_sp(t_inv, t) for t ∈ t_inv if has_penalty(c_up, t)))
    else
        penalty_up_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end

    if length(constraints_down) > 0
        c_down = first(constraints_down)
        penalty_down_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], sum(m[:gate_penalty_down][n, t, p] *
            penalty(c_down, t) * scale_op_sp(t_inv, t) for t ∈ t_inv if has_penalty(c_down, t)))
    else
        penalty_down_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == opex_var[t_inv] + penalty_up_var[t_inv] +
            penalty_down_var[t_inv]
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
                m[:stor_level][n, t] * opex_var(level(n), t) * scale_op_sp(t_inv, t) for
                t ∈ t_inv
            )
        )
    else
        opex_var_level = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end
    if EMB.has_charge_OPEX_var(n)
        opex_var_charge = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
            sum(
                m[:stor_charge_use][n, t] * opex_var(charge(n), t) * scale_op_sp(t_inv, t)
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
                scale_op_sp(t_inv, t) for t ∈ t_inv
            )
        )
    else
        opex_var_discharge = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end

    # Create the constraint penalty constraint
    constraints = constraint_data(n)
    constraints_up = filter(has_penalty_up, constraints) # Max and schedule
    constraints_down = filter(has_penalty_down, constraints) # Min and schedule

    p = storage_resource(n)
    if length(constraints_up) > 0
        c_up = first(constraints_up)
        penalty_up_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], sum(m[:rsv_penalty_up][n, t, p] *
            penalty(c_up, t) * scale_op_sp(t_inv, t) for t ∈ t_inv if has_penalty(c_up, t)))
    else
        penalty_up_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end

    if length(constraints_down) > 0
        c_down = first(constraints_down)
        penalty_down_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], sum(m[:rsv_penalty_down][n, t, p] *
            penalty(c_down, t) * scale_op_sp(t_inv, t) for t ∈ t_inv if has_penalty(c_down, t)))
    else
        penalty_down_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end

    # Create the overall constraint
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == opex_var_level[t_inv] + opex_var_charge[t_inv] +
            opex_var_discharge[t_inv] + penalty_up_var[t_inv] + penalty_down_var[t_inv]
    )
end

"""
EMB.constraints_opex_var(m, n::HydroUnit, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `HydroUnit`.
This function relates the penalty costs for violating constraints to the objective.
"""
function EMB.constraints_opex_var(m, n::HydroUnit, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    constraints = constraint_data(n)

    opex_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], sum(m[:cap_use][n, t] * EMB.opex_var(n, t) *
        scale_op_sp(t_inv, t) for t ∈ t_inv))

    penalty_up_var = Dict(t_inv => AffExpr(0) for t_inv ∈ 𝒯ᴵⁿᵛ)
    penalty_down_var = Dict(t_inv => AffExpr(0) for t_inv ∈ 𝒯ᴵⁿᵛ)

    penalty_up_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(penalty(c, t) * scale_op_sp(t_inv, t) * m[:gen_penalty_up][n, t, p]
            for t ∈ t_inv
            for p ∈ [water_resource(n), electricity_resource(n)]
            for c in constraints
            if has_penalty_up(c, t, p)
        )
    )
    penalty_down_var = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(penalty(c, t) * scale_op_sp(t_inv, t) * m[:gen_penalty_down][n, t, p]
            for t ∈ t_inv
            for p ∈ [water_resource(n), electricity_resource(n)]
            for c in constraints
            if has_penalty_down(c, t, p)
        )
    )

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == opex_var[t_inv] + penalty_up_var[t_inv] +
            penalty_down_var[t_inv]
    )
end

"""
    build_constraint(m, n::Node, c::Constraint, 𝒯::TimeStructure, p::ResourceCarrier)

Create minimum/maximum/schedule discharge constraints for the generic `Node` type. The
`Constraint{T}` can have types `T <: AbstractConstraintType` that defines the direction of
the constraint.
Penalty variables are included unless penalty value is not set or `Inf``.
"""
function build_constraint(m, n::EMB.Node, c::Constraint{MinConstraintType},
    𝒯::TimeStructure, p::ResourceCarrier, var_name, penalty_name)

    @constraint(m, [t ∈ 𝒯; is_active(c, t) & has_penalty(c, t)],
        m[Symbol(var_name)][n, t, p] + m[Symbol(penalty_name * "_up")][n, t, p] ≥
        EMB.capacity(n, t, p) * value(c, t))
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & !has_penalty(c, t)],
        m[Symbol(var_name)][n, t, p] ≥ EMB.capacity(n, t, p) * value(c, t))
end
function build_constraint(m, n::EMB.Node, c::Constraint{MaxConstraintType},
    𝒯::TimeStructure, p::ResourceCarrier, var_name, penalty_name)

    @constraint(m, [t ∈ 𝒯; is_active(c, t) & has_penalty(c, t)],
        m[Symbol(var_name)][n, t, p] - m[Symbol(penalty_name * "_down")][n, t, p] ≤
        EMB.capacity(n, t, p) * value(c, t))
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & !has_penalty(c, t)],
        m[Symbol(var_name)][n, t, p] ≤ EMB.capacity(n, t, p) * value(c, t))
end
function build_constraint(m, n::EMB.Node, c::Constraint{ScheduleConstraintType},
    𝒯::TimeStructure, p::ResourceCarrier, var_name, penalty_name)
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & has_penalty(c, t)],
        m[Symbol(var_name)][n, t, p] + m[Symbol(penalty_name * "_up")][n, t, p] -
        m[Symbol(penalty_name * "_down")][n, t, p] == EMB.capacity(n, t, p) * value(c, t))
    for t ∈ 𝒯
        if is_active(c, t) & !has_penalty(c, t)
            JuMP.fix(m[Symbol(var_name)][n, t, p], EMB.capacity(n, t, p) * value(c, t); force=true)
        end
    end
end

"""
    constraints_flow_out(m, n::HydroGate, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the outlet flow from a `HydroGate`.
This function implements the schedule and min/max constraints if present.
"""
function EMB.constraints_flow_out(m, n::HydroGate, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒫ᵒᵘᵗ = outputs(n)
    # HydroGate should always have only one input/output resource
    p = first(𝒫ᵒᵘᵗ)

    # Constraint for the individual output stream connections
    @constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, p] == m[:cap_use][n, t] * outputs(n, p))

    # If HydroGate has constraint data, build the required constraints
    for c in constraint_data(n)
        build_constraint(m, n, c, 𝒯, p, "flow_out", "gate_penalty")
    end
end

"""
    constraints_capacity(m, n::HydroUnit, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraints on the maximum capacity of a [`HydroUnit`](@ref) node.

!!! warning "Dispatching on this function"
    If you create a new method for this function, it is crucial to call within said function
    the function `constraints_capacity_installed(m, n, 𝒯, modeltype)` if you want to include
    investment options.
"""
function EMB.constraints_capacity(m, n::HydroUnit, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯], m[:cap_use][n, t] <= m[:cap_inst][n, t] * max_power(n))

    constraints_capacity_installed(m, n, 𝒯, modeltype)
end

"""
    build_pq_constaints(m, n::HydroUnit, c::PqPoints, 𝒯::TimeStructure)

Function for creating the constraints on the flow_out, cap_use and discharge_segments 
    variables definedrelated by the pq_curve for a `HydroUnit`node.
"""
function build_pq_constaints(m, n::HydroUnit, c::PqPoints, 𝒯::TimeStructure)

    Q = discharge_segments(c)
    η = [(c.power_levels[q+1] - c.power_levels[q]) /
            (c.discharge_levels[q+1] - c.discharge_levels[q])
            for q ∈ Q]

    # Range of discharge segments
    @constraint(m, [t ∈ 𝒯, q ∈ Q], m[:discharge_segment][n, t, q] ≤
        capacity(n, t) * (c.discharge_levels[q+1].- c.discharge_levels[q]))

    @constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, water_resource(n) ] ==
        sum(m[:discharge_segment][n, t, q] for q ∈ Q))

    @constraint(m, [t ∈ 𝒯], m[:cap_use][n, t] ==
        sum(m[:discharge_segment][n, t, q]* η[q] for q ∈ Q))
end

"""
    constraints_flow_in(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the inlet flow from a HydroGenerator Node.
"""
function EMB.constraints_flow_in(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯], m[:flow_in][n, t, water_resource(n) ] ==
        m[:flow_out][n, t, water_resource(n)])
end

"""
    constraints_flow_in(m, n::HydroPump, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the inlet flow from a HydroPump Node.
"""
function EMB.constraints_flow_in(m, n::HydroPump, 𝒯::TimeStructure, modeltype::EnergyModel)

    build_pq_constaints(m, n, pq_curve(n), 𝒯)
    @constraint(m, [t ∈ 𝒯], m[:flow_in][n, t, electricity_resource(n)] ==
        m[:cap_use][n, t])

    for c in constraint_data(n)
        build_constraint(m, n, c, 𝒯, c.resource, "flow_in", "gen_penalty")
    end
end

"""
    constraints_flow_out(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the outlet flow from a HydroGenerator Node.
"""
function EMB.constraints_flow_out(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)

    build_pq_constaints(m, n, pq_curve(n), 𝒯)
    @constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, electricity_resource(n)] ==
        m[:cap_use][n, t])

    for c in constraint_data(n)
        build_constraint(m, n, c, 𝒯, c.resource, "flow_out", "gen_penalty")
    end
end

"""
    constraints_flow_out(m, n::HydroPump, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the outlet flow from a HydroPump Node.
"""
function EMB.constraints_flow_out(m, n::HydroPump, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, water_resource(n) ] ==
        m[:flow_in][n, t, water_resource(n)])
end
