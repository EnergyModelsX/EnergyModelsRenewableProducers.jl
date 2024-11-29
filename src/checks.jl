"""
    EMB.check_node(n::NonDisRES, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that the *[`NonDisRES`](@ref)* node is valid.

It reuses the standard checks of a `Source` node through calling the function
[`EMB.check_node_default`](@extef EnergyModelsBase.check_node_default), but adds an
additional check on the data.

## Checks
 - The field `cap` is required to be non-negative (similar to the `Source` check).
 - The value of the field `fixed_opex` is required to be non-negative and
   accessible through a `StrategicPeriod` as outlined in the function
   `check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`.
 - The values of the dictionary `output` are required to be non-negative
   (similar to the `Source` check).
 - The field `profile` is required to be in the range ``[0, 1]`` for all time steps
   ``t ∈ \\mathcal{T}``.
"""
function EMB.check_node(n::NonDisRES, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    EMB.check_node_default(n, 𝒯, modeltype, check_timeprofiles)
    @assert_or_log(
        all(profile(n, t) ≤ 1 for t ∈ 𝒯),
        "The profile field must be less or equal to 1."
    )
    @assert_or_log(
        all(profile(n, t) ≥ 0 for t ∈ 𝒯),
        "The profile field must be non-negative."
    )
end

"""
    EMB.check_node(n::HydroStorage, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that the *[`HydroStorage`](@ref)* node is valid.

It reuses the standard checks of a `Storage` node through calling the function
[`EMB.check_node_default`](@extef EnergyModelsBase.check_node_default), but adds an
additional check on the data.

## Checks
- The `TimeProfile` of the field `capacity` in the type in the field `charge` is required
  to be non-negative if the chosen composite type has the field `capacity`.
- The `TimeProfile` of the field `capacity` in the type in the field `level` is required
  to be non-negative`.
- The `TimeProfile` of the field `capacity` in the type in the field `discharge` is required
  to be non-negative if the chosen composite type has the field `capacity`.
- The `TimeProfile` of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  `check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)` for the chosen composite type .
 - The field `output` can only include a single `Resource`.
 - The value of the field `output` is required to be in the range ``[0, 1]``.
 - The value of the field `input` is required to be in the range ``[0, 1]``.
 - The value of the field `level_init` is required to be in the range
   ``[level\\_min, 1] \\cdot stor\\_cap(t)`` for all time steps ``t ∈ \\mathcal{T}``.
 - The value of the field `level_init` is required to be in the range ``[0, 1]``.
 - The value of the field `level_min` is required to be in the range ``[0, 1]``.
"""
function EMB.check_node(n::HydroStorage, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    par_level = level(n)

    EMB.check_node_default(n, 𝒯, modeltype, check_timeprofiles)
    @assert_or_log(
        length(outputs(n)) == 1,
        "Only one resource can be stored, so only this one can flow out."
    )
    has_input(n) && @assert_or_log(
        all(inputs(n, p) ≤ 1 for p ∈ inputs(n)),
        "The values for the Dictionary `input` must be less than or equal to 1."
    )
    has_output(n) && @assert_or_log(
        all(outputs(n, p) ≤ 1 for p ∈ outputs(n)),
        "The values for the Dictionary `output` must be less than or equal to 1."
    )

    @assert_or_log(
        all(level_init(n, t) ≤ capacity(par_level, t) for t ∈ 𝒯),
        "The initial level `level_init` has to be less or equal to the max storage capacity."
    )
    for t_inv ∈ 𝒯ᴵⁿᵛ
        t = first(t_inv)
        # Check that the reservoir isn't underfilled from the start.
        @assert_or_log(
            level_init(n, t_inv) + level_inflow(n, t) ≥ level_min(n, t) * capacity(par_level, t),
            "The reservoir cannot be underfilled from the start (" * string(t) * ").")
    end
    @assert_or_log(
        all(level_init(n, t) ≥ 0 for t ∈ 𝒯),
        "The field `level_init` cannot be negative."
    )
    @assert_or_log(
        all(level_min(n, t) ≥ 0 for t ∈ 𝒯),
        "The field `level_min` cannot be negative."
    )
    @assert_or_log(
        all(level_min(n, t) ≤ 1 for t ∈ 𝒯),
        "The field `level_min` cannot be larger than 1."
    )
end

"""
    EMB.check_node(n::HydroReservoir, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that the [`HydroReservoir`](@ref) node is valid.

## Checks
- The `TimeProfile` of the `capacity` of the `HydroReservoir` `level` is required
  to be non-negative.
- The `TimeProfile` of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  `check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)` for the chosen composite type.
- The `TimeProfile` of the `vol_inflow` of the `HydroReservoir` is required to be
  non-negative.
"""
function EMB.check_node(n::HydroReservoir, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    par_level = level(n)

    if isa(par_level, EMB.UnionCapacity)
        @assert_or_log(
            all(capacity(par_level, t) ≥ 0 for t ∈ 𝒯),
            "The volume capacity has to be non-negative."
        )
    end
    if isa(par_level, EMB.UnionOpexFixed)
        EMB.check_fixed_opex(par_level, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    @assert_or_log(
        all(vol_inflow(n, t) ≥ 0 for t ∈ 𝒯),
        "The field `vol_inflow` has to be non-negative."
    )
end

"""
    EMB.check_node(n::HydroGate, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that the *[`HydroGate`](@ref)* node is valid.

## Checks
 - The field `cap` is required to be non-negative.
"""
function EMB.check_node(n::HydroGate, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )
end

"""
    EMB.check_node(n::HydroUnit, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that the [`HydroGenerator`](@ref) and [`HydroPump`](@ref) nodes are valid.

## Checks
- The field `cap` is required to be non-negative.
- The [`PqPoints`](@ref) vectors are required to have the same length.
- The [`PqPoints`](@ref) vectors should start at 0.
- The [`PqPoints`](@ref) vectors are required to be increasing.
- One of the [`PqPoints`](@ref) vectors should have values between 0 and 1.
- The [`PqPoints`](@ref) curve should be concave for generators and convex for pumps.
- The value of the field `fixed_opex` is required to be non-negative and accessible through
  a `StrategicPeriod` as outlined in the function [`EMB.check_fixed_opex()`](@extref EnergyModelsBase.check_fixed_opex).
"""
function EMB.check_node(n::HydroUnit, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )

    pq = pq_curve(n)
    if pq isa PqPoints
        @assert_or_log(
            length(power_level(pq)) == length(discharge_level(pq)),
            "The `PqPoint` vectors must have the same length."
        )

        @assert_or_log(
            (power_level(pq, 1) ≈ 0) & (discharge_level(pq, 1) ≈ 0),
            "The `PqPoint` vectors should start at 0."
        )

        @assert_or_log(
            issorted(power_level(pq), lt= <=) & issorted(discharge_level(pq), lt= <=),
            "The `PqPoint` vectors must be increasing."
        )
        n_p = length(power_level(pq))
        n_d = length(discharge_level(pq))
        @assert_or_log(
            ((power_level(pq, 1) ≈ 0) & (power_level(pq, n_p) ≈ 1)) |
            ((discharge_level(pq, 1) ≈ 0) & (discharge_level(pq, n_d) ≈ 1)),
            "One of the `PqPoint` vectors should be from 0 to 1."
        )

        if n isa HydroGenerator
            @assert_or_log(
                issorted(
                    (power_level(pq)[2:end] - power_level(pq)[1:end-1]) ./
                        (discharge_level(pq)[2:end] - discharge_level(pq)[1:end-1]),
                    rev=true, lt= <=
                ),
                "The `PqPoint` curve should be concave for generators."
            )
        else
            @assert_or_log(
                issorted(
                    (power_level(pq)[2:end] - power_level(pq)[1:end-1]) ./
                        (discharge_level(pq)[2:end] - discharge_level(pq)[1:end-1]),
                    rev=false, lt= <=
                ),
                "The `PqPoint` curve should be convex for pumps."
            )
        end
    end
    EMB.check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
end

"""
    EMB.check_node_data(n::EMB.Node, data::ScheduleConstraint, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Performs various checks on [`ScheduleConstraint`](@ref) data for all nodes.

## Checks
- The the field `resource` is required to be a valid resource of the node.
- The value of constraints are required to be in the range ``[0, 1]`` for all time steps
  ``t ∈ \\mathcal{T}``.
- The penalty of constraints are required to be non-negative for all time steps
  ``t ∈ \\mathcal{T}``.
"""
function EMB.check_node_data(
    n::EMB.Node,
    data::ScheduleConstraint,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)
    if isa(n, HydroUnit)
        @assert_or_log(
            (resource(data) == water_resource(n)) |
                (resource(data) == electricity_resource(n)),
            "The constraint resource must be either the water or electricity resource."
        )
    end
    @assert_or_log(
        all(0 ≤ value(data, t) ≤ 1 for t ∈ 𝒯),
        "The relative constraint value must be between 0 and 1."
    )
    @assert_or_log(
        all(penalty(data, t) ≥ 0 for t ∈ 𝒯),
        "The penalty must be non-negative."
    )
end

"""
    EMB.check_node(n::AbstractBattery, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that the *[`AbstractBattery`](@ref)* node is valid.

It reuses the standard checks of a `Storage` node through calling the function
[`EMB.check_node_default`](@extef EnergyModelsBase.check_node_default), but adds an
additional check on the data.

## Checks
- The `TimeProfile` of the field `capacity` in the type in the field `charge` is required
  to be non-negative.
- The `TimeProfile` of the field `capacity` in the type in the field `level` is required
  to be non-negative`.
- The `TimeProfile` of the field `capacity` in the type in the field `discharge` is required
  to be non-negative.
- The `TimeProfile` of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  `check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)` for the chosen composite type .
- The field `output` can only include a single `Resource`.
- The value of the field `input` is required to be in the range ``[0, 1]``.
- The value of the field `output` is required to be in the range ``[0, 1]``
- The [`AbstractBatteryLife`](@ref) must follow the provided values as outlined in the
  function [`check_battery_life`](@ref).
"""
function EMB.check_node(n::AbstractBattery, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    EMB.check_node_default(n, 𝒯, modeltype, check_timeprofiles)
    has_input(n) && @assert_or_log(
        all(inputs(n, p) ≤ 1 for p ∈ inputs(n)),
        "The values for the Dictionary `input` must be less than or equal to 1."
    )
    has_output(n) && @assert_or_log(
        all(outputs(n, p) ≤ 1 for p ∈ outputs(n)),
        "The values for the Dictionary `output` must be less than or equal to 1."
    )
    check_battery_life(n, battery_life(n), 𝒯, modeltype, check_timeprofiles)
end

"""
    EMB.check_node(n::ReserveBattery, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that the *[`ReserveBattery`](@ref)* node is valid.

It reuses the standard checks of a `Storage` node through calling the function
[`EMB.check_node_default`](@extef EnergyModelsBase.check_node_default), but adds an
additional check on the data.

## Checks
- The `TimeProfile` of the field `capacity` in the type in the field `charge` is required
  to be non-negative.
- The `TimeProfile` of the field `capacity` in the type in the field `level` is required
  to be non-negative`.
- The `TimeProfile` of the field `capacity` in the type in the field `discharge` is required
  to be non-negative.
- The `TimeProfile` of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  `check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)` for the chosen composite type .
- The field `output` can only include a single `Resource`.
- The value of the field `input` is required to be in the range ``[0, 1]``.
- The value of the field `output` is required to be in the range ``[0, 1]``
- The resources in the array `reserve_up` cannot be part of the resources in the dictionaries
  dictionaries `input` and `output`.
- The resources in the array `reserve_down` cannot be part of the resources in the
  dictionaries `input` and `output`.
"""
function EMB.check_node(n::ReserveBattery, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    EMB.check_node_default(n, 𝒯, modeltype, check_timeprofiles)
    has_input(n) && @assert_or_log(
        all(inputs(n, p) ≤ 1 for p ∈ inputs(n)),
        "The values for the Dictionary `input` must be less than or equal to 1."
    )
    has_output(n) && @assert_or_log(
        all(outputs(n, p) ≤ 1 for p ∈ outputs(n)),
        "The values for the Dictionary `output` must be less than or equal to 1."
    )
    check_battery_life(n, battery_life(n), 𝒯, modeltype, check_timeprofiles)
    if !isempty(reserve_up(n))
        @assert_or_log(
            any([!haskey(n.input, p) for p ∈ reserve_up(n)]),
            "The `reserve_up` resources cannot be in the `input` dictionary."
        )
        @assert_or_log(
            any([!haskey(n.output, p) for p ∈ reserve_up(n)]),
            "The `reserve_up` resources cannot be in the `output` dictionary."
        )
    end
    if !isempty(reserve_down(n))
        @assert_or_log(
            any([!haskey(n.input, p) for p ∈ reserve_down(n)]),
            "The `reserve_down` resources cannot be in the `input` dictionary."
        )
        @assert_or_log(
            any([!haskey(n.output, p) for p ∈ reserve_down(n)]),
            "The `reserve_down` resources cannot be in the `output` dictionary."
        )
    end
end

"""
check_battery_life(n::AbstractBattery, bat_life::AbstractBatteryLife, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
check_battery_life(n::AbstractBattery, bat_life::CycleLife, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Check that the included [`AbstractBatteryLife`](@ref) types of an [`AbstractBattery`](@ref)
follows to the

## Checks [`AbstractBatteryLife`](@ref)
- None.

## Checks [`CycleLife`](@ref)
- All fields must be positive.
- The value of the field `degradation` must be smaller than 1.
- The value of the field `stack_cost` is required to be accessible through a
  `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex`](@extref EnergyModelsBase.check_fixed_opex).
"""
function check_battery_life(
    n::AbstractBattery,
    bat_life::AbstractBatteryLife,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)
end
function check_battery_life(
    n::AbstractBattery,
    bat_life::CycleLife,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @assert_or_log(
        cycles(bat_life) > 0,
        "The value of the field `cycles` in the `CycleLife` must be positive."
    )
    @assert_or_log(
        degradation(bat_life) > 0,
        "The value of the field `degradation` in the `CycleLife` must be positive."
    )
    @assert_or_log(
        degradation(bat_life) ≤ 1,
        "The value of the field `degradation` in the `CycleLife` must be smaller or equal to 1."
    )

    if isa(stack_cost(bat_life), StrategicProfile) && check_timeprofiles
        @assert_or_log(
            length(stack_cost(bat_life).vals) == length(𝒯ᴵⁿᵛ),
            "The timeprofile provided for the field `stack_cost` does not match the " *
            "strategic structure."
        )
    end

    # Check for potential indexing problems
    message = "are not allowed for the field `stack_cost`."
    bool_sp = EMB.check_strategic_profile(stack_cost(n), message)

    # Check that the value is positive in all cases
    if bool_sp
        @assert_or_log(
            all(stack_cost(bat_life, t_inv) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ),
            "The values of the timeprofiles of the field `stack_cost` in the `CycleLife` " *
            "must be positive."
        )
    end
end
