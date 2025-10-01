"""
    EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{MinSchedule})
    EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{MaxSchedule})
    EMB.constraints_ext_data(m, n::HydroNode, 𝒯, 𝒫, modeltype::EnergyModel, data::ScheduleConstraint{EqualSchedule})

Constraint functions for creating constraints regarding production schedule for the individual
units within a waterway as declared through [`HydroNode`](@ref). The constraints can either
be hard (if the penalty is set to `Inf`) or soft (for any other value).

The chosen scheduling variables are identified using the function [`get_var_schedule`](@ref)
while the capacity to which the profile should apply is identified through the function
[`get_var_inst`](@ref).

There exist several configurations:
- **[`MaxSchedule`](@ref)** corresponds to minimum constraints,
- **[`MinSchedule`](@ref)** corresponds to maximum constraints, and
- **[`EqualSchedule`](@ref)** corresponds to equality constraints.
"""
function EMB.constraints_ext_data(
    m,
    n::HydroNode,
    𝒯,
    𝒫,
    modeltype::EnergyModel,
    data::ScheduleConstraint{MinSchedule},
)
    # Extract the variables
    var_schedule = get_var_schedule(m, n, 𝒯, data)
    var_pen_up = get_var_pen_up(m, n, 𝒯, data)
    var_inst = get_var_inst(m, n, 𝒯, data)

    # Add the constraints for the scheduling variable
    @constraint(m, [t ∈ 𝒯; is_active(data, t) & has_penalty(data, t)],
        var_schedule[t] + var_pen_up[t] ≥ var_inst[t] * value(data, t)
    )
    @constraint(m, [t ∈ 𝒯; is_active(data, t) & !has_penalty(data, t)],
        var_schedule[t] ≥ var_inst[t] * value(data, t)
    )
end
function EMB.constraints_ext_data(
    m,
    n::HydroNode,
    𝒯,
    𝒫,
    modeltype::EnergyModel,
    data::ScheduleConstraint{MaxSchedule},
)
    # Extract the variables
    var_schedule = get_var_schedule(m, n, 𝒯, data)
    var_pen_down = get_var_pen_down(m, n, 𝒯, data)
    var_inst = get_var_inst(m, n, 𝒯, data)

    # Add the constraints for the scheduling variable
    @constraint(m, [t ∈ 𝒯; is_active(data, t) & has_penalty(data, t)],
        var_schedule[t] - var_pen_down[t] ≤ var_inst[t] * value(data, t)
    )
    @constraint(m, [t ∈ 𝒯; is_active(data, t) & !has_penalty(data, t)],
        var_schedule[t] ≤ var_inst[t] * value(data, t)
    )
end
function EMB.constraints_ext_data(
    m,
    n::HydroNode,
    𝒯,
    𝒫,
    modeltype::EnergyModel,
    data::ScheduleConstraint{EqualSchedule},
)
    # Extract the variables
    var_schedule = get_var_schedule(m, n, 𝒯, data)
    var_pen_up = get_var_pen_up(m, n, 𝒯, data)
    var_pen_down = get_var_pen_down(m, n, 𝒯, data)
    var_inst = get_var_inst(m, n, 𝒯, data)

    # Add the constraints for the scheduling variable
    @constraint(m, [t ∈ 𝒯; is_active(data, t) & has_penalty(data, t)],
        var_schedule[t] + var_pen_up[t] - var_pen_down[t] == var_inst[t] * value(data, t)
    )
    @constraint(m, [t ∈ 𝒯; is_active(data, t) & !has_penalty(data, t)],
        var_schedule[t] == var_inst[t] * value(data, t)
    )
end
