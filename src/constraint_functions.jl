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
    constraints_capacity(m, n::AbstractBattery, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the maximum capacity of an [`AbstractBattery`](@ref).

Its function flow is changed from the standard approach through calling the function
[`capacity_reduction`](@ref) to identify the reduced storage capacity, depending on the
chosen [`AbstractBatteryLife`](@ref) type.
"""
function EMB.constraints_capacity(m, n::AbstractBattery, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Identify the reduction in storage level capacity
    stor_level_red = capacity_reduction(m, n, 𝒯, modeltype)

    # Introduce the required constraints based on the installed capacity
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] ≤
            m[:stor_level_inst][n, t] - stor_level_red[t]
    )
    @constraint(m, [t ∈ 𝒯], m[:stor_charge_use][n, t] ≤ m[:stor_charge_inst][n, t])
    @constraint(m, [t ∈ 𝒯], m[:stor_discharge_use][n, t] ≤ m[:stor_discharge_inst][n, t])

    # Call of the function for determining the installed capacity
    constraints_capacity_installed(m, n, 𝒯, modeltype)
end

"""
    constraints_reserve(m, n::AbstractBattery, 𝒯::TimeStructure, modeltype::EnergyModel)
    constraints_reserve(m, n::ReserveBattery, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the additional constraints on the capacity utilization to account
for providing reserve capacity to the system.

!!! tip "Default approach"
    No constraints are added.

!!! note "`ReserveBattery`"
    Several constraints are added to guarantee that the provided reserve can be delivered
    through the values of the variables `:stor_charge_use`, `stor_discharge_use`,
    and `stor_level`.
"""
constraints_reserve(m, n::AbstractBattery, 𝒯::TimeStructure, modeltype::EnergyModel) = nothing
function constraints_reserve(m, n::ReserveBattery, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Identify the reduction in storage level capacity
    stor_level_red = capacity_reduction(m, n, 𝒯, modeltype)

    # Add the reserve constraints
    @constraint(m, [t ∈ 𝒯],
        m[:stor_discharge_use][n, t] - m[:stor_charge_use][n, t] + m[:bat_res_up][n, t]
            ≤ m[:stor_discharge_inst][n, t]
    )
    @constraint(m, [t ∈ 𝒯],
        m[:stor_charge_use][n, t] - m[:stor_discharge_use][n, t] + m[:bat_res_down][n, t]
            ≤ m[:stor_charge_inst][n, t]
    )
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] + m[:bat_res_down][n, t]
            ≤ m[:stor_level_inst][n, t] - stor_level_red[t]
    )
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] - m[:bat_res_up][n, t]
            ≥ 0
    )
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
    constraints_flow_out(m, n::ReserveBattery, 𝒯::TimeStructure, modeltype::EnergyModel)

When `n::ReserveBattery`, the variable `:flow_out` is also declared for the different
reserve resources as identified through the functions [`reserve_up`](@ref) and
[`reserve_down`](@ref).
"""
function EMB.constraints_flow_out(m, n::ReserveBattery, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets
    p_stor = storage_resource(n)

    # Constraint for the individual input stream connections
    @constraint(m, [t ∈ 𝒯],
        m[:flow_out][n, t, p_stor] == m[:stor_discharge_use][n, t]
    )

    # Constraint for storage reserve up delivery
    @constraint(m, [t ∈ 𝒯],
        m[:bat_res_up][n, t] == sum(m[:flow_out][n, t, p] for p in reserve_up(n))
    )

    # Constraint for storage reserve down delivery
    @constraint(m, [t ∈ 𝒯],
        m[:bat_res_down][n, t] == sum(m[:flow_out][n, t, p] for p in reserve_down(n))
    )
end

"""
    constraints_level_aux(m, n::HydroStorage, 𝒯, 𝒫, modeltype)

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
    constraints_level_aux(m, n::AbstractBattery, 𝒯, 𝒫, modeltype::EnergyModel)

Function for creating the Δ constraint for the level of an [`AbstractBattery`](@ref)
node utilizing the efficiencies declared in inputs and outputs of the storage resource.
"""
function EMB.constraints_level_aux(m, n::AbstractBattery, 𝒯, 𝒫, modeltype::EnergyModel)
    # Declaration of the required subsets
    p_stor = storage_resource(n)

    # Constraint for the change in the level in a given operational period
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] ==
            m[:stor_charge_use][n, t] * inputs(n, p_stor) -
            m[:stor_discharge_use][n, t] / outputs(n, p_stor)
    )
end
"""
    constraints_usage(m, n::AbstractBattery, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the usage constraints for an `AbstractBattery`. These constraints
calculate the usage of the battery up to each time step for the lifetime calculations.
"""
function constraints_usage(m, n::AbstractBattery, 𝒯, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    p_stor = storage_resource(n)

    # Mass/energy balance constraints for stored energy carrier.
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        # Creation of the iterator and call of the iterator function -
        # The representative period is initiated with the current investment period to allow
        # dispatching on it.
        prev_pers = PreviousPeriods(t_inv_prev, nothing, nothing);
        cyclic_pers = CyclicPeriods(t_inv, t_inv)
        ts = t_inv.operational

        # Constraint for the total usage in a given strategic period
        @constraint(m,
            m[:bat_use_sp][n, t_inv] ==
                sum(
                    m[:stor_charge_use][n, t] * inputs(n, p_stor) * scale_op_sp(t_inv, t)
                for t ∈ t_inv)
        )

        # Constraint for calculating the charging utilization before the current strategic
        # period
        constraints_usage_sp(m, n, prev_pers, t_inv, modeltype)

        # Iterate through the time structure for calculation of the individual charging
        # cycles
        constraints_usage_iterate(m, n, prev_pers, cyclic_pers, t_inv, t_inv, ts, modeltype)
    end
end
"""
    constraints_usage_sp(
        m,
        n::AbstractBattery,
        prev_pers::PreviousPeriods,
        t_inv::TS.AbstractStrategicPeriod,
        modeltype::EnergyModel,
    )

Function for creating the constraints on the previous usage of an [`AbstractBattery`](@ref)
before the beginning of a strategic period.

In the case of the first strategic period, it fixes the variable `bat_prev_use_sp` to 0.
In all subsequent strategic periods, the previous usage is calculated.
"""
function constraints_usage_sp(
    m,
    n::AbstractBattery,
    prev_pers::PreviousPeriods{Nothing, Nothing, Nothing},
    t_inv::TS.AbstractStrategicPeriod,
    modeltype::EnergyModel,
)

    JuMP.fix(m[:bat_prev_use_sp][n, t_inv], 0; force=true)
end
function constraints_usage_sp(
    m,
    n::AbstractBattery,
    prev_pers::PreviousPeriods{<:TS.AbstractStrategicPeriod, Nothing, Nothing},
    t_inv::TS.AbstractStrategicPeriod,
    modeltype::EnergyModel,
)
    disjunct = replace_disjunct(m, n, battery_life(n), prev_pers, t_inv, modeltype)
    @constraint(m,
        m[:bat_prev_use_sp][n, t_inv] == disjunct
    )
end

"""
    constraints_usage_iterate(
        m,
        n::AbstractBattery,
        prev_pers::PreviousPeriods,
        cyclic_pers::CyclicPeriods,
        t_inv::TS.AbstractStrategicPeriod,
        per,
        ts::RepresentativePeriods,
        modeltype::EnergyModel,
    )

Iterate through the individual time structures of an [`AbstractBattery`](@ref) node.

In the case of `RepresentativePeriods`, additional constraints are calculated for the usage
of the electrolyzer in representative periods through introducing the variable
`bat_use_rp[𝒩ᴱᴸ, 𝒯ʳᵖ]`.
 """
function constraints_usage_iterate(
    m,
    n::AbstractBattery,
    prev_pers::PreviousPeriods,
    cyclic_pers::CyclicPeriods,
    t_inv::TS.AbstractStrategicPeriod,
    per,
    _::RepresentativePeriods,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒯ʳᵖ = repr_periods(per)
    last_rp = last(𝒯ʳᵖ)
    p_stor = storage_resource(n)

    # Constraint for the total usage in a given representative period
    @constraint(m, [t_rp ∈ 𝒯ʳᵖ],
        m[:bat_use_rp][n, t_rp] ==
            sum(
                m[:stor_charge_use][n, t] * inputs(n, p_stor) * scale_op_sp(per, t)
            for t ∈ t_rp)
    )

    # Iterate through the operational structure
    for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ)
        prev_pers = PreviousPeriods(EMB.strat_per(prev_pers), t_rp_prev, EMB.op_per(prev_pers));
        cyclic_pers = CyclicPeriods(last_rp, t_rp)
        ts = t_rp.operational.operational
        constraints_usage_iterate(m, n, prev_pers, cyclic_pers, t_inv, t_rp, ts, modeltype)
    end
end
"""
In the case of `OperationalScenarios`, we purely iterate through the individual time
structures.
"""
function constraints_usage_iterate(
    m,
    n::AbstractBattery,
    prev_pers::PreviousPeriods,
    cyclic_pers::CyclicPeriods,
    t_inv::TS.AbstractStrategicPeriod,
    per,
    _::OperationalScenarios,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒯ˢᶜ = opscenarios(per)

    # Iterate through the operational structure
    for t_scp ∈ 𝒯ˢᶜ
        ts = t_scp.operational.operational
        constraints_usage_iterate(m, n, prev_pers, cyclic_pers, t_inv, t_scp, ts, modeltype)
    end
end

"""
In the case of `SimpleTimes`, the iterator function is at its lowest level. In this
situation,the previous usage is calculated using the function [`previous_usage`](@ref).
The approach for calculating the constraints is depending on the types in the parameteric
type [`EMB.PreviousPeriods`](@extref EnergyModelsBase.PreviousPeriods).
"""
function constraints_usage_iterate(
    m,
    n::AbstractBattery,
    prev_pers::PreviousPeriods,
    cyclic_pers::CyclicPeriods,
    t_inv::TS.AbstractStrategicPeriod,
    per,
    _::SimpleTimes,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    p_stor = storage_resource(n)

    # Constraint for the total charging of the battery including the current time step.
    # This ensures that the last repetition of the strategic period is appropriately
    # constrained.
    # The conditional statement activates this constraint only for the last representative
    # period, if representative periods are present as stack replacement is only feasible
    # once per strategic period
    if last_per(cyclic_pers) == current_per(cyclic_pers) && !isnothing(cycles(n))
        t = last(per)
        @constraint(m,
            cycles(n) * m[:stor_level_inst][n, t] ≥
                m[:bat_prev_use][n, t] +
                m[:bat_use_sp][n, t_inv] * duration_strat(t_inv)
        )
    end

    # Iterate through the operational structure
    for (t_prev, t) ∈ withprev(per)
        prev_pers = PreviousPeriods(strat_per(prev_pers), rep_per(prev_pers), t_prev);

        # Add the constraints for the previous usage
        prev_use = previous_usage(m, n, t_inv, prev_pers, modeltype)

        @constraint(m,
            m[:bat_prev_use][n, t] ==
                prev_use + m[:stor_charge_use][n, t] * inputs(n, p_stor) * duration(t)
        )
    end
end

"""
    constraints_opex_fixed(m, n::AbstractBattery, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the fixed OPEX of a generic [`AbstractBattery`](@ref).

The functions nodes includes fixed OPEX for `charge`, `level`, and `discharge` if the node
has the corresponding storage parameter. The individual contributions are in all situations
calculated based on the installed capacities.

In addition, stack replacement is included if the `battery_life` has a limited cycle lifetime.
The division by duration_strat(t_inv) for the stack replacement is requried due to
multiplication with the duration in the objective function calculation.
"""
function EMB.constraints_opex_fixed(m, n::AbstractBattery, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

    # Extracts the contribution from the individual components
    if EMB.has_level_OPEX_fixed(n)
        opex_fixed_level = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
            m[:stor_level_inst][n, first(t_inv)] * opex_fixed(level(n), t_inv)
        )
    else
        opex_fixed_level = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end
    if EMB.has_charge_OPEX_fixed(n)
        opex_fixed_charge = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
            m[:stor_charge_inst][n, first(t_inv)] * opex_fixed(charge(n), t_inv)
        )
    else
        opex_fixed_charge = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end
    if EMB.has_discharge_OPEX_fixed(n)
        opex_fixed_discharge = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
            m[:stor_discharge_inst][n, first(t_inv)] * opex_fixed(discharge(n), t_inv)
        )
    else
        opex_fixed_discharge = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end
    if has_degradation(n)
        # Extraction of the stack replacement variable
        stack_replace = multiplication_variables(m, n, 𝒯ᴵⁿᵛ, modeltype)
        opex_fixed_degradation = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
            stack_replace[t_inv] * stack_cost(n)
            )
    else
        opex_fixed_degradation = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
    end

    # Create the overall constraint
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_fixed][n, t_inv] ==
        opex_fixed_level[t_inv] + opex_fixed_charge[t_inv] + opex_fixed_discharge[t_inv] +
        opex_fixed_degradation[t_inv] / duration_strat(t_inv)
    )
end

#! format: on

"""
    build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::ScheduleConstraint, 𝒯)

Create minimum/maximum/schedule volume constraints for a [`HydroReservoir`](@ref) node. The
`ScheduleConstraint{T}` can have types `T <: AbstractScheduleType` that defines the direction of
the constraint.

Penalty variables are included unless the  penalty value is not set or `Inf`.
"""
function build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::ScheduleConstraint{MinSchedule}, 𝒯)
    p = storage_resource(n)
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & has_penalty(c, t)],
        m[:stor_level][n, t] + m[:rsv_penalty_up][n, t, p] ≥ EMB.capacity(EMB.level(n), t) * value(c, t))
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & !has_penalty(c, t)],
        m[:stor_level][n, t] ≥ EMB.capacity(EMB.level(n), t) * value(c, t))
end
function build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::ScheduleConstraint{MaxSchedule}, 𝒯)
    p = storage_resource(n)
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & has_penalty(c, t)],
        m[:stor_level][n, t] - m[:rsv_penalty_down][n, t, p] ≤ EMB.capacity(EMB.level(n), t) * value(c, t))
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & !has_penalty(c, t)],
        m[:stor_level][n, t] ≤ EMB.capacity(EMB.level(n), t) * value(c, t))
end
function build_hydro_reservoir_vol_constraints(m, n::HydroReservoir, c::ScheduleConstraint{EqualSchedule}, 𝒯)
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

Create the Δ constraint for the level of the [`HydroReservoir`](@ref) node. The change in
storage level in the reservoir at operational periods `t` is the flow into the reservoir
through the variable `stor_charge_use` and inflow (through the function `vol_inflow`) minus
the flow out of the reservoir through the variable `stor_discharge_use`.

In addition, it creates the volume constraints if data is provided.
"""
function EMB.constraints_level_aux(m, n::HydroReservoir{T} where T<:EMB.StorageBehavior,
    𝒯, 𝒫, modeltype::EnergyModel)

    # Constraint for the change in the level in a given operational period
    @constraint(
        m, [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] ==
            vol_inflow(n, t) + m[:stor_charge_use][n, t] - m[:stor_discharge_use][n, t])

    # The minimum and maximum contents of the reservoir is bounded below and above.
    for c ∈ constraint_data(n)
        build_hydro_reservoir_vol_constraints(m, n, c, 𝒯)
    end
end

"""
    EMB.constraints_opex_var(m, n::HydroResevoir{T}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    EMB.constraints_opex_var(m, n::HydroGate, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    EMB.constraints_opex_var(m, n::HydroUnit, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Method for creating the constraint on the variable OPEX.
The individual methods extend the functions of `EnergyModelsBase` through incorporating the
penalty term for constraint violation.
"""
function EMB.constraints_opex_var(m, n::HydroGate, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

    # Identification of the individual constraints
    constraints = constraint_data(n)
    constraints_up = filter(has_penalty_up, constraints)
    constraints_down = filter(has_penalty_down, constraints)

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
    build_schedule_constraint(m, n::Union{HydroGate, HydroUnit}, c::ScheduleConstraint, 𝒯::TimeStructure, p::ResourceCarrier)

Create minimum/maximum/schedule discharge constraints for the generic `Node` type. The
`ScheduleConstraint{T}` can have types `T <: AbstractScheduleType` that defines the direction of
the constraint.
Penalty variables are included unless penalty value is not set or `Inf``.
"""
function build_schedule_constraint(
    m,
    n::Union{HydroGate, HydroUnit},
    c::ScheduleConstraint{MinSchedule},
    𝒯::TimeStructure,
    p::ResourceCarrier,
    var_name,
    penalty_name
)

    @constraint(m, [t ∈ 𝒯; is_active(c, t) & has_penalty(c, t)],
        m[Symbol(var_name)][n, t, p] + m[Symbol(penalty_name * "_up")][n, t, p] ≥
            EMB.capacity(n, t, p) * value(c, t)
    )
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & !has_penalty(c, t)],
        m[Symbol(var_name)][n, t, p] ≥
            EMB.capacity(n, t, p) * value(c, t)
    )
end
function build_schedule_constraint(
    m,
    n::Union{HydroGate, HydroUnit},
    c::ScheduleConstraint{MaxSchedule},
    𝒯::TimeStructure,
    p::ResourceCarrier,
    var_name,
    penalty_name
)
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & has_penalty(c, t)],
        m[Symbol(var_name)][n, t, p] - m[Symbol(penalty_name * "_down")][n, t, p] ≤
            EMB.capacity(n, t, p) * value(c, t)
    )
    @constraint(m, [t ∈ 𝒯; is_active(c, t) & !has_penalty(c, t)],
        m[Symbol(var_name)][n, t, p] ≤
            EMB.capacity(n, t, p) * value(c, t)
    )
end
function build_schedule_constraint(m,
    n::Union{HydroGate, HydroUnit},
    c::ScheduleConstraint{EqualSchedule},
    𝒯::TimeStructure,
    p::ResourceCarrier,
    var_name,
    penalty_name,
)

    @constraint(m, [t ∈ 𝒯; is_active(c, t) & has_penalty(c, t)],
        m[Symbol(var_name)][n, t, p] + m[Symbol(penalty_name * "_up")][n, t, p] -
        m[Symbol(penalty_name * "_down")][n, t, p] ==
            EMB.capacity(n, t, p) * value(c, t)
    )
    for t ∈ 𝒯
        if is_active(c, t) & !has_penalty(c, t)
            JuMP.fix(m[Symbol(var_name)][n, t, p], EMB.capacity(n, t, p) * value(c, t); force=true)
        end
    end
end

"""
    EMB.constraints_flow_out(m, n::HydroGate, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the outlet flow from a `HydroGate`.
This function implements the schedule and min/max constraints if present.
"""
function EMB.constraints_flow_out(m, n::HydroGate, 𝒯::TimeStructure, modeltype::EnergyModel)
    # HydroGate should always have only one input/output resource
    p = first(outputs(n))

    # Constraint for the individual output stream connections
    @constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, p] == m[:cap_use][n, t] * outputs(n, p))

    # If HydroGate has constraint data, build the required constraints
    for c in constraint_data(n)
        build_schedule_constraint(m, n, c, 𝒯, p, "flow_out", "gate_penalty")
    end
end

"""
    EMB.constraints_capacity(m, n::HydroUnit, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraints on the maximum capacity of a [`HydroUnit`](@ref) node.
It differs from the base functions through incorporating the PQ Curve through the function
[`max_normalized_power`](@ref)

Furthermore, the function [`build_pq_constaints`](@ref) is called for creating additional
constraints on the capacity utilization.

!!! warning "Dispatching on this function"
    If you create a new method for this function, it is crucial to call within said function
    the function `constraints_capacity_installed(m, n, 𝒯, modeltype)` if you want to include
    investment options.
"""
function EMB.constraints_capacity(m, n::HydroUnit, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯], m[:cap_use][n, t] ≤ m[:cap_inst][n, t] * max_normalized_power(n))
    build_pq_constaints(m, n, pq_curve(n), 𝒯)

    constraints_capacity_installed(m, n, 𝒯, modeltype)
end

"""
    build_pq_constaints(m, n::HydroUnit, c::PqPoints, 𝒯::TimeStructure)

Function for creating the constraints on the variables `flow_out`, `cap_use`, and
`discharge_segments` as declared in the PqPoints `pq` of a [`HydroUnit`](@ref) node.
"""
function build_pq_constaints(m, n::HydroUnit, pq::PqPoints, 𝒯::TimeStructure)

    Q = discharge_segments(pq)
    η = [(power_level(pq, q+1) - power_level(pq, q)) /
            (discharge_level(pq, q+1) - discharge_level(pq, q))
            for q ∈ Q]

    # Range of discharge segments
    @constraint(m, [t ∈ 𝒯, q ∈ Q],
        m[:discharge_segment][n, t, q] ≤
            capacity(n, t) * (discharge_level(pq, q+1).- discharge_level(pq, q))
    )

    @constraint(m, [t ∈ 𝒯],
        m[:flow_out][n, t, water_resource(n)] ==
            sum(m[:discharge_segment][n, t, q] for q ∈ Q)
    )

    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] ==
            sum(m[:discharge_segment][n, t, q]* η[q] for q ∈ Q)
    )
end

"""
    EMB.constraints_flow_in(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)
    EMB.constraints_flow_in(m, n::HydroPump, 𝒯::TimeStructure, modeltype::EnergyModel)

Method for creating the constraint on the inlet flow of a node `n`.

!!! tip "`HydroGenerator`"
    The constraints enforce that the water inlet flow is equal to the outlet flow at each
    operational period `t`, and hence, preserve conservation of mass.
!!! note "`HydroPump`"
    The electricity flow to the unit is equal to the capacity utilization
    The flow of the inlet resources can be constrained through calling the function
    [`build_schedule_constraint`](@ref).
"""
function EMB.constraints_flow_in(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯],
        m[:flow_in][n, t, water_resource(n) ] ==
            m[:flow_out][n, t, water_resource(n)]
    )
end
function EMB.constraints_flow_in(m, n::HydroPump, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯],
        m[:flow_in][n, t, electricity_resource(n)] ==
            m[:cap_use][n, t]
    )

    for c ∈ constraint_data(n)
        build_schedule_constraint(m, n, c, 𝒯, resource(c), "flow_in", "gen_penalty")
    end
end

"""
    EMB.constraints_flow_out(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)
    EMB.constraints_flow_out(m, n::HydroPump, 𝒯::TimeStructure, modeltype::EnergyModel)

Method for creating the constraint on the oulet flow of a node `n`.

!!! tip "`HydroGenerator`"
    - The electricity flow from the unit is equal to the capacity utilization.
    - The flow of the inlet resources can be constrained through calling the function
      [`build_schedule_constraint`](@ref).
!!! note "`HydroPump`"
    - The constraints enforce that the water outlet flow is equal to the inlet flow at each
      operational period `t`, and hence, preserve conservation of mass.
"""
function EMB.constraints_flow_out(m, n::HydroGenerator, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯],
        m[:flow_out][n, t, electricity_resource(n)] ==
            m[:cap_use][n, t]
    )

    for c ∈ constraint_data(n)
        build_schedule_constraint(m, n, c, 𝒯, resource(c), "flow_out", "gen_penalty")
    end
end
function EMB.constraints_flow_out(m, n::HydroPump, 𝒯::TimeStructure, modeltype::EnergyModel)
    @constraint(m, [t ∈ 𝒯],
        m[:flow_out][n, t, water_resource(n)] ==
            m[:flow_in][n, t, water_resource(n)]
    )
end
