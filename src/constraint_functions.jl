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


function build_pq_constaints(m, n::HydroGenerator, c::EnergyEquivalent, 𝒯::TimeStructure)

     # water inn = water out
     @constraint(m, [t ∈ 𝒯],
     m[:flow_out][n, t, water_resource(n)] == m[:cap_use][n, t] * outputs(n, water_resource(n))
     )

     # Relatinship between discharge of water and power generated
     @constraint(m, [t ∈ 𝒯],
     m[:flow_out][n, t, electricity_resource(n)] == m[:cap_use][n, t] * c.value
     )

end


function build_pq_constaints(m, n::HydroGenerator, c::PqPoints, 𝒯::TimeStructure)

    η = Real[]
    for i in range(2, length(c.dischargeLevels))
        push!(η, (c.powerLevels[i] - c.powerLevels[i-1]) / (c.dischargeLevels[i] - c.dischargeLevels[i-1]))
    end

    @constraint(m, [t ∈ 𝒯],
    m[:flow_out][n, t, water_resource(n)] == m[:cap_use][n, t] * outputs(n, water_resource(n))
    )
    
    # produksjon = discharge_segment*virkningsgrad_segment
    Q = range(1,number_of_discharge_points(c)-1)

    @constraint(m, [t ∈ 𝒯, q ∈  Q],
    m[:discharge_segment][n, t, q] <= c.dischargeLevels[q+1].- c.dischargeLevels[q] #m3/timeunit (or Mm3/timeunit)
    )

    # max(dischargeLevels) == installed_capacity?
    @constraint(m, [t ∈ 𝒯],
    m[:cap_use][n, t] == sum(m[:discharge_segment][n, t, q] for q ∈ Q)
    )

    # dischargeLevels må være samme enhet som 
    @constraint(m, [t ∈ 𝒯],
    m[:flow_out][n, t, electricity_resource(n) ] == sum(m[:discharge_segment][n, t, q]* η[q] for q ∈ Q)
    )

end

#=
function build_pq_constaints(m, n::HydroGenerator, c::PqEfficiencyCurve, 𝒯::TimeStructure)

    @constraint(m, [t ∈ 𝒯],
    m[:flow_out][n, t, water_resource(n)] == m[:cap_use][n, t] * outputs(n, water_resource(n))
    )
    
    # produksjon = discharge_segment*virkningsgrad_segment
    Q = range(1,number_of_discharge_points(c)-1)


    @constraint(m, [t ∈ 𝒯, q ∈  Q],
    m[:discharge_segment][n, t, q] <= (c.dischargeLevels[q+1] .- c.dischargeLevels[q])*20 #m[:cap_inst[n,t]]
    )

    @constraint(m, [t ∈ 𝒯],
    m[:cap_use][n, t] == sum(m[:discharge_segment][n, t, q] for q ∈ Q)
    )

    η = Real[]
    ρ = 1000 #kg/m3
    g = 9.81 #9,81 m/s²
    f_p = 1/(10^3*3600) #J/m3 --> kWh/m3

    for i in range(1, length(c.efficiency))
        push!(η, (ρ*g*c.refHead*c.efficiency[i])*f_p) #kWh/m3
    end

    # Mm3/timestep --> m3/s  -->10^6/(3600*duration(t))
    
    @constraint(m, [t ∈ 𝒯],
    m[:flow_out][n, t, electricity_resource(n) ] == sum(m[:discharge_segment][n, t, q]*η[q]*10^6/(3600*duration(t))*(1/10^3) for q ∈ Q) #MW
    ) 

end
=#

"""
    constraints_flow_out(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the outlet flow from a HydroGenerator Node.
"""
function EMB.constraints_flow_out(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets, excluding CO2, if specified


    # Constraint for the individual output stream connections
    # produksjon = discharge*energy equivalent
    # NB: If PQ-curve is being used, the energy equivalent must be >= best efficiency
    # TODO: overwrite energy equivalent if PQ-curve given
    # TODO: update energy equivalent if only one value in PQ-curve


    #𝒫ᵒᵘᵗ = EMB.res_not(outputs(n), co2_instance(modeltype))
    #𝒫ⁱⁿ  = EMB.res_not(inputs(n), co2_instance(modeltype))
    #new_resource = 𝒫ᵒᵘᵗ[𝒫ᵒᵘᵗ .∉ [𝒫ⁱⁿ]] # Power
    #original_resource = 𝒫ᵒᵘᵗ[𝒫ᵒᵘᵗ .∈ [𝒫ⁱⁿ]] # Water
    
    # Since the type of resource is defined by the user it is not convenient to set conditions
    # based on the type (naming conventions or spelling can vary, e.g. water/hydro or power/electricity).



    build_pq_constaints(m, n, pq_curve(n), 𝒯)


end
