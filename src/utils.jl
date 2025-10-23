"""
    capacity_reduction(
        m,
        n::AbstractBattery,
        bat_life::AbstractBatteryLife,
        𝒯::TimeStructure,
        modeltype::EnergyModel,
    )

Returns the reduction in the storage capacity of an [`AbstractBattery`](@ref) depending once
on the chosen [`AbstractBatteryLife`](@ref).

!!! tip "Default approach"
    Returns a value of 0 indicating no reduction in storage capacity.

!!! note "`CycleLife`"
    Returns the reduction in storage level capacity as linear multiplier of the charge usage
    of the Battery through the fields `cycles` and `degradation` of the [`CycleLife`](@ref).
"""
capacity_reduction(m, n::AbstractBattery, 𝒯::TimeStructure, modeltype::EnergyModel) =
    capacity_reduction(m, n, battery_life(n), 𝒯, modeltype)
function capacity_reduction(
    m,
    n::AbstractBattery,
    bat_life::AbstractBatteryLife,
    𝒯::TimeStructure,
    modeltype::EnergyModel,
)
    return @expression(m, [t ∈ 𝒯], 0)
end
function capacity_reduction(
    m,
    n::AbstractBattery,
    bat_life::CycleLife,
    𝒯::TimeStructure,
    modeltype::EnergyModel,
)
    return @expression(m, [t ∈ 𝒯],
        degradation(bat_life) * m[:bat_prev_use][n, t] / cycles(bat_life)
    )
end

"""
    replace_disjunct(
        m,
        n::AbstractBattery,
        bat_life::AbstractBatteryLife,
        prev_pers::PreviousPeriods,
        t_inv::TS.AbstractStrategicPeriod,
        modeltype::EnergyModel,
    )

Function for dispatching no the different type of battery lifes for incorporation of the
preivous usage constraints in the first operational period (of the first representative
period) of a strategic period.

!!! tip "Default approach"
    Returns the value based on the the calculation of the previous usage in the previous
    strategic period and the initial value in the previous strategic period.

!!! note "`CycleLife`"
    In the case of a cycle life, it takes into account the potential for battery stack replacement
    through a bilinear formulation. The bilinear formulation is simplifed due to the known
    lower bounds.
"""
function replace_disjunct(
    m,
    n::AbstractBattery,
    bat_life::AbstractBatteryLife,
    prev_pers::PreviousPeriods,
    t_inv::TS.AbstractStrategicPeriod,
    modeltype::EnergyModel,
)
    t_inv_prev = strat_per(prev_pers)
    return @expression(m,
        # Initial usage in previous sp
        m[:bat_prev_use_sp][n, t_inv_prev] +
        # Increase in previous representative period
        m[:bat_use_sp][n, t_inv_prev] * duration_strat(t_inv_prev)
    )
end
function replace_disjunct(
    m,
    n::AbstractBattery,
    bat_life::CycleLife,
    prev_pers::PreviousPeriods,
    t_inv::TS.AbstractStrategicPeriod,
    modeltype::EnergyModel,
)
    t_inv_prev = strat_per(prev_pers)

    # Calculate the expression if no battery stack replacement is taking place
    replace =  @expression(m,
        # Initial usage in previous sp
        m[:bat_prev_use_sp][n, t_inv_prev] +
        # Increase in previous representative period
        m[:bat_use_sp][n, t_inv_prev] * duration_strat(t_inv_prev)
    )

    # Introduce the auxiliary variable
    ub = capacity_max(n, t_inv, modeltype)
    var_aux = @variable(m, lower_bound = 0, upper_bound = ub)

    # Constraints for the linear reformulation. The constraints are based on the
    # McCormick envelopes which result in an exact reformulation for the multiplication
    # of a binary and a continuous variable.
    @constraints(m, begin
        var_aux ≥ ub * ( - m[:bat_stack_replace_b][n, t_inv]) + replace
        var_aux ≤ ub * (1 - m[:bat_stack_replace_b][n, t_inv])
        var_aux ≤ replace
    end)
    return var_aux
end

"""
    previous_usage(
        m,
        n::AbstractBattery,
        t_inv::TS.AbstractStrategicPeriod,
        prev_pers::PreviousPeriods,
        modeltype::EnergyModel,
    )

Returns the previous usage of an `AbstractBattery` node depending on the type of
[`PreviousPeriods`](@extref EnergyModelsBase.PreviousPeriods).

The basic functionality is used in the case when the previous operational period is a
`TimePeriod`, in which case it just returns the previous operational period.
"""
function previous_usage(
    m,
    n::AbstractBattery,
    t_inv::TS.AbstractStrategicPeriod,
    prev_pers::PreviousPeriods,
    modeltype::EnergyModel,
)
    t_prev = op_per(prev_pers)
    return @expression(m, m[:bat_prev_use][n, t_prev])
end
"""
When the previous operational and representative periods are `Nothing`, the variable
`bat_prev_use_sp` is used for the initial usage in a strategic period
"""
function previous_usage(
    m,
    n::AbstractBattery,
    t_inv::TS.AbstractStrategicPeriod,
    prev_pers::PreviousPeriods{<:EMB.NothingPeriod, Nothing, Nothing},
    modeltype::EnergyModel,
)
    # Return the previous usage through the variable `bat_prev_use_sp`
    return @expression(m, m[:bat_prev_use_sp][n, t_inv])
end
"""
When the previous operational period is `Nothing` and the previous representative period an
`AbstractRepresentativePeriod` then the time structure *does* include `RepresentativePeriods`.

The constraint then sums up the values from the previous representative period.
"""
function previous_usage(
    m,
    n::AbstractBattery,
    t_inv::TS.AbstractStrategicPeriod,
    prev_pers::PreviousPeriods{<:EMB.NothingPeriod, <:TS.AbstractRepresentativePeriod, Nothing},
    modeltype::EnergyModel,
)
    t_rp_prev = rep_per(prev_pers)
    p_stor = storage_resource(n)
    return @expression(m,
        # Initial usage in previous rp
        m[:bat_prev_use][n, first(t_rp_prev)] -
        m[:stor_charge_use][n, first(t_rp_prev)] * inputs(n, p_stor) *
        duration(first(t_rp_prev)) +
        # Increase in previous representative period
        m[:bat_use_rp][n, t_rp_prev]
    )
end

"""
    linear_reformulation(
        m,
        𝒯,
        var_binary,
        var_continuous,
        lb::TimeProfile,
        ub::TimeProfile,
    )

Linear reformulation of the element-wise multiplication of the binary variable `var_binary[𝒯]`
and the continuous variable `var_continuous[𝒯] ∈ [ub, lb]`.

It returns the product `var_aux[𝒯]` with

``var\\_aux[t] = var\\_binary[t] \\times var\\_continuous[t]``.

!!! note
    The bounds `lb` and `ub` must have the ability to access their fields using the iterator
    of `𝒯`, that is if `𝒯` corresponds to the strategic periods, it is not possible to
    provide an `OperationalProfile` or `RepresentativeProfile`.
"""
function linear_reformulation(
    m,
    𝒯,
    var_binary,
    var_continuous,
    lb::TimeProfile,
    ub::TimeProfile,
    )

    # Declaration of the auxiliary variable
    var_aux = @variable(m, [t ∈ 𝒯], lower_bound = minimum([0, lb[t]]), upper_bound = ub[t])

    # Constraints for the linear reformulation. The constraints are based on the
    # McCormick envelopes which result in an exact reformulation for the multiplication
    # of a binary and a continuous variable.
    @constraints(m, begin
        [t ∈ 𝒯], var_aux[t] ≥ lb[t] * var_binary[t]
        [t ∈ 𝒯], var_aux[t] ≥ ub[t] * (var_binary[t]-1) + var_continuous[t]
        [t ∈ 𝒯], var_aux[t] ≤ ub[t] * var_binary[t]
        [t ∈ 𝒯], var_aux[t] ≤ lb[t] * (var_binary[t]-1) + var_continuous[t]
    end)

    return var_aux
end

"""
    multiplication_variables(
        m,
        n::AbstractBattery,
        𝒯ᴵⁿᵛ,
        modeltype::EnergyModel
    )

Function for calculating the muliplication of the capacity of an [`AbstractBattery`](@ref)
and the binary variable `:bat_stack_replace_b`.

    modeltype::EnergyModel

Multiplication of the installed capacity (expressed through `capacity(level(n), t_inv)`) and
the binary variable `bat_stack_replace_b` in a strategic period `t_inv`.

## Returns
- **`prod[t]`**: Multiplication of `capacity(level(n), t_inv)` and
  `bat_stack_replace_b[n, t_inv]`.


    modeltype::AbstractInvestmentModel

When the modeltype is an `AbstractInvestmentModel`, then the function applies a linear
reformulation of the binary-continuous multiplication based on the McCormick relaxation and
the function [`linear_reformulation`](@ref).

!!! note
    If the [`AbstractBattery`](@ref) node does not have investments, it reuses the
    default function to avoid increasing the number of variables in the model.

## Returns
- **`prod[t]`**: Multiplication of `cap_inst[n, t]` and `var_b[t]` or alternatively
  `cap_current[n, t]` and `var_b[t]`, if the TimeStructure is a `StrategicPeriods` and
  the node `n` has investments.
"""
function multiplication_variables(
    m,
    n::AbstractBattery,
    𝒯ᴵⁿᵛ,
    modeltype::EnergyModel
)
    # Calculation of the multiplication with the installed capacity of the node
    prod = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        capacity(level(n), t_inv) * m[:bat_stack_replace_b][n, t_inv]
    )
    return prod
end

"""
    capacity_max(n::AbstractBattery, t_inv, modeltype::EnergyModel)

Function for calculating the maximum capacity, including the number of cycles.

    modeltype::EnergyModel

When the modeltype is an `EnergyModel`, it returns the muliplication of the installed
storage level capacity and the number of cycles before the stack must be replaced.

    modeltype::AbstractInvestmentModel

When the modeltype is an `AbstractInvestmentModel`, it returns the muliplication of the
maximum installed storage level capacity and the number of cycles before the stack must be
replaced.

!!! note
    If the [`AbstractBattery`](@ref) node does not have investments, it reuses the
    default function.
"""
capacity_max(n::AbstractBattery, t_inv, modeltype::EnergyModel) =
    capacity(level(n), t_inv) * cycles(n)

"""
    get_var_inst(m, n::HydroReservoir, 𝒯::TimeStructure, data::ScheduleConstraint)
    get_var_inst(m, n::HydroGate, 𝒯::TimeStructure, data::ScheduleConstraint)
    get_var_inst(m, n::HydroUnit, 𝒯::TimeStructure, data::ScheduleConstraint)

Extracts the installed capacity variable used in scheduling constraints. The variables are

* `n::HydroReservoir` - `:stor_level_inst[n, :]`,
* `n::HydroGate` - `:cap_inst[n, :]`, and
* `n::HydroUnit` - `:cap_inst[n, :]` multiplied by the value for the node of the function
  [`max_normalized_flow`](@ref) or [`max_normalized_power`](@ref).
"""
get_var_inst(m, n::HydroReservoir, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:stor_level_inst][n, :]
get_var_inst(m, n::HydroGate, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:cap_inst][n, :]
function get_var_inst(m, n::HydroUnit, 𝒯::TimeStructure, data::ScheduleConstraint)
    p = resource(data)
    if p == electricity_resource(n)
        mult = max_normalized_power(n)
    elseif p == water_resource(n)
        mult = max_normalized_flow(n)
    end
    return @expression(m, [t ∈ 𝒯], m[:cap_inst][n, t] * mult)
end

"""
    get_var_schedule(m, n::HydroReservoir, 𝒯::TimeStructure, data::ScheduleConstraint)
    get_var_schedule(m, n::HydroGate, 𝒯::TimeStructure, data::ScheduleConstraint)
    get_var_schedule(m, n::HydroPump, 𝒯::TimeStructure, data::ScheduleConstraint)
    get_var_schedule(m, n::HydroGenerator, 𝒯::TimeStructure, data::ScheduleConstraint)

Extracts the variable for which scheduling constraints are included. The variables are

* `n::HydroReservoir` - `:stor_level[n, :]`,
* `n::HydroGate` - `:flow_out[n, :, n.resource]`,
* `n::HydroPump` - `:flow_in[n, :, resource(data)]`, and
* `n::HydroGenerator` - `:flow_out[n, :, resource(data)]`.
"""
get_var_schedule(m, n::HydroReservoir, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:stor_level][n, :]
get_var_schedule(m, n::HydroGate, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:flow_out][n, :, n.resource]
get_var_schedule(m, n::HydroPump, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:flow_in][n, :, resource(data)]
get_var_schedule(m, n::HydroGenerator, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:flow_out][n, :, resource(data)]

"""
    get_var_pen_up(m, n::HydroReservoir, 𝒯::TimeStructure, data::ScheduleConstraint)
    get_var_pen_up(m, n::HydroGate, 𝒯::TimeStructure, data::ScheduleConstraint)
    get_var_pen_up(m, n::HydroUnit, 𝒯::TimeStructure, data::ScheduleConstraint)
    get_var_pen_up(m, n::HydroReservoir, t::TS.TimePeriod, data::ScheduleConstraint)
    get_var_pen_up(m, n::HydroGate, t::TS.TimePeriod, data::ScheduleConstraint)
    get_var_pen_up(m, n::HydroUnit, t::TS.TimePeriod, data::ScheduleConstraint)

Extracts the variable for which scheduling constraints are included indexed over the
`TimeStructure` or in operational period `t`. The variables are

* `n::HydroReservoir` - `:rsv_penalty_up[n, :, storage_resource(n)]`,
* `n::HydroGate` - `:gate_penalty_up[n, :, n.resource]`, and
* `n::HydroUnit` - `:gen_penalty_up[n, :, resource(data)]`.
"""
get_var_pen_up(m, n::HydroReservoir, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:rsv_penalty_up][n, :, storage_resource(n)]
get_var_pen_up(m, n::HydroGate, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:gate_penalty_up][n, :, n.resource]
get_var_pen_up(m, n::HydroUnit, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:gen_penalty_up][n, :, resource(data)]
get_var_pen_up(m, n::HydroReservoir, t::TS.TimePeriod, data::ScheduleConstraint) =
    m[:rsv_penalty_up][n, t, storage_resource(n)]
get_var_pen_up(m, n::HydroGate, t::TS.TimePeriod, data::ScheduleConstraint) =
    m[:gate_penalty_up][n, t, n.resource]
get_var_pen_up(m, n::HydroUnit, t::TS.TimePeriod, data::ScheduleConstraint) =
    m[:gen_penalty_up][n, t, resource(data)]

"""
    get_var_pen_down(m, n::HydroReservoir, 𝒯::TimeStructure, data::ScheduleConstraint)
    get_var_pen_down(m, n::HydroGate, 𝒯::TimeStructure, data::ScheduleConstraint)
    get_var_pen_down(m, n::HydroUnit, 𝒯::TimeStructure, data::ScheduleConstraint)
    get_var_pen_down(m, n::HydroReservoir, t::TS.TimePeriod, data::ScheduleConstraint)
    get_var_pen_down(m, n::HydroGate, t::TS.TimePeriod, data::ScheduleConstraint)
    get_var_pen_down(m, n::HydroUnit, t::TS.TimePeriod, data::ScheduleConstraint)

Extracts the variable for which scheduling constraints are included indexed over the
`TimeStructure` or in operational period `t`. The variables are

* `n::HydroReservoir` - `:rsv_penalty_down[n, :, storage_resource(n)]`,
* `n::HydroGate` - `:gate_penalty_down[n, :, n.resource]`, and
* `n::HydroUnit` - `:gen_penalty_down[n, :, resource(data)]`.
"""
get_var_pen_down(m, n::HydroReservoir, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:rsv_penalty_down][n, :, storage_resource(n)]
get_var_pen_down(m, n::HydroGate, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:gate_penalty_down][n, :, n.resource]
get_var_pen_down(m, n::HydroUnit, 𝒯::TimeStructure, data::ScheduleConstraint) =
    m[:gen_penalty_down][n, :, resource(data)]
get_var_pen_down(m, n::HydroReservoir, t::TS.TimePeriod, data::ScheduleConstraint) =
    m[:rsv_penalty_down][n, t, storage_resource(n)]
get_var_pen_down(m, n::HydroGate, t::TS.TimePeriod, data::ScheduleConstraint) =
    m[:gate_penalty_down][n, t, n.resource]
get_var_pen_down(m, n::HydroUnit, t::TS.TimePeriod, data::ScheduleConstraint) =
    m[:gen_penalty_down][n, t, resource(data)]

"""
    get_opex_pen_up(m, n::HydroNode, sched_data::Vector{<:ScheduleConstraint}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    get_opex_pen_up(m, n::HydroNode, sched_data::Vector{<:ExtensionData}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Returns the contribution of [`HydroNode`](@ref) `n` for the minimum or equality penalty
violation to the variable OPEX.
"""
function get_opex_pen_up(
    m,
    n::HydroNode,
    sched_data::Vector{<:ScheduleConstraint},
    𝒯ᴵⁿᵛ,
    modeltype::EnergyModel,
)
    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(
            get_var_pen_up(m, n, t, pen_active) * penalty(pen_active, t) *
            scale_op_sp(t_inv, t)
        for t ∈ t_inv for pen_active ∈ sched_data if has_penalty(pen_active, t))
    )
end
function get_opex_pen_up(
    m,
    n::HydroNode,
    sched_data::Vector{<:ExtensionData},
    𝒯ᴵⁿᵛ,
    modeltype::EnergyModel,
)
    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
end

"""
    get_opex_pen_down(m, n::HydroNode, sched_data::Vector{<:ScheduleConstraint}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    get_opex_pen_down(m, n::HydroNode, sched_data::Vector{<:ExtensionData}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Returns the contribution of [`HydroNode`](@ref) `n` for the maximum or equality penalty
violation to the variable OPEX for each investment period `t_inv`.
"""
function get_opex_pen_down(
    m,
    n::HydroNode,
    sched_data::Vector{<:ScheduleConstraint},
    𝒯ᴵⁿᵛ,
    modeltype::EnergyModel,
)
    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(
            get_var_pen_down(m, n, t, pen_active) * penalty(pen_active, t) *
            scale_op_sp(t_inv, t)
        for t ∈ t_inv for pen_active ∈ sched_data if has_penalty(pen_active, t))
    )
end
function get_opex_pen_down(
    m,
    n::HydroNode,
    sched_data::Vector{<:ExtensionData},
    𝒯ᴵⁿᵛ,
    modeltype::EnergyModel,
)
    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)
end
