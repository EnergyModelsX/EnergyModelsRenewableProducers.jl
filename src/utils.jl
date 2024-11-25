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
    previous_usage(
        m,
        n::AbstractBattery,
        t_inv::TimeStruct.AbstractStrategicPeriod,
        prev_pers::PreviousPeriods,
        modeltype::EnergyModel,
    )

Returns the previous usage of an `AbstractBattery` node depending on the type of
[`PreviousPeriods`](@ref).

The basic functionality is used in the case when the previous operational period is a
`TimePeriod`, in which case it just returns the previous operational period.
"""
function previous_usage(
    m,
    n::AbstractBattery,
    t_inv::TimeStruct.AbstractStrategicPeriod,
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
    t_inv::TimeStruct.AbstractStrategicPeriod,
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
    t_inv::TimeStruct.AbstractStrategicPeriod,
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
        m[:bat_usage_rp][n, t_rp_prev]
    )
end
