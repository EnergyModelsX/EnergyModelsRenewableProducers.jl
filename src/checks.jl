"""
    EMB.check_node_default(n::AbstractNonDisRES, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method provides the default checks for all [`AbstractNonDisRES`](@ref) nodes. It is
called by [`EMB.check_node`](@extref EnergyModelsBase.check_node) unless a subtype defines
its own `check_node` method, in which case it can call this function.

## Checks
- The field `cap` is required to be non-negative (similar to the `Source` check).
- The value of the field `opex_fixed` is required to be non-negative and accessible through
  a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex`](@extref EnergyModelsBase.check_fixed_opex).
- The values of the dictionary `output` are required to be non-negative (similar to the
  `Source` check).
- The field `profile` is required to be in the range ``[0, 1]`` for all time steps
  ``t ∈ \\mathcal{T}``.
"""
function EMB.check_node_default(
    n::AbstractNonDisRES,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        all(outputs(n, p) ≥ 0 for p ∈ outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    EMB.check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)

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

This method checks that the [`HydroStorage`](@ref) node is valid.

It reuses the standard checks of a `Storage` node through calling the function
[`EMB.check_node_default`](@extref EnergyModelsBase.check_node_default), but adds an
additional check on the data.

## Checks
- The `TimeProfile` of the field `capacity` in the type in the field `charge` is required to
  be non-negative if the chosen composite type has the field `capacity`.
- The `TimeProfile` of the field `capacity` in the type in the field `level` is required to
  be non-negative.
- The `TimeProfile` of the field `capacity` in the type in the field `discharge` is required
  to be non-negative if the chosen composite type has the field `capacity`.
- The `TimeProfile` of the field `opex_fixed` is required to be non-negative and accessible
  through a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex`](@extref EnergyModelsBase.check_fixed_opex) for the chosen
  composite type.
- The field `output` can only include a single `Resource`.
- The value of the field `output` is required to be less than or equal to 1.
- The value of the field `input` is required to be less than or equal to 1.
- The value of the field `level_init` is required to be non-negative and less than or equal
  to the storage capacity for all time steps ``t ∈ \\mathcal{T}``.
- The sum of the fields `level_init` and `level_inflow` in the first operational period of
  each strategic period is required to be at least the minimum level
  ``level\\_min \\cdot stor\\_cap(t)``.
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
            level_init(n, t) + level_inflow(n, t) ≥ level_min(n, t) * capacity(par_level, t),
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
- The `TimeProfile` of the `capacity` of the `HydroReservoir` field `vol` is required to be
  non-negative.
- The `TimeProfile` of the field `opex_fixed` is required to be non-negative and accessible
  through a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex`](@extref EnergyModelsBase.check_fixed_opex) for the field `vol`,
  if included.
- The `TimeProfile` of the `vol_inflow` of the `HydroReservoir` is required to be non-negative.
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

This method checks that the [`HydroGate`](@ref) node is valid.

## Checks
- The field `cap` is required to be non-negative.
- The value of the field `opex_fixed` is required to be non-negative and accessible through
  a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex`](@extref EnergyModelsBase.check_fixed_opex).
"""
function EMB.check_node(n::HydroGate, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )
    EMB.check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
end

"""
    EMB.check_node(n::HydroUnit, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that the [`HydroGenerator`](@ref) and [`HydroPump`](@ref) nodes are valid.

## Checks
- The field `cap` is required to be non-negative.
- The [`PqPoints`](@ref) vectors are required to have the same length and at least two points.
- The [`PqPoints`](@ref) vectors should start at 0.
- The [`PqPoints`](@ref) vectors are required to be strictly increasing.
- One of the [`PqPoints`](@ref) vectors should range from 0 to 1.
- The [`PqPoints`](@ref) curve should be concave for generators and convex for pumps. Linear
  segments, that is equal slopes, are allowed.
- The value of the field `opex_fixed` is required to be non-negative and accessible through
  a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex`](@extref EnergyModelsBase.check_fixed_opex).
"""
function EMB.check_node(n::HydroUnit, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )

    pq = pq_curve(n)
    if isa(pq, PqPoints)
        n_p = length(power_level(pq))
        n_d = length(discharge_level(pq))
        @assert_or_log(
            n_p == n_d,
            "The `PqPoint` vectors must have the same length."
        )
        @assert_or_log(
            (n_p ≥ 2) & (n_d ≥ 2),
            "The `PqPoint` vectors must have at least two points."
        )

        if (n_p ≥ 1) & (n_d ≥ 1)
            @assert_or_log(
                (power_level(pq, 1) ≈ 0) & (discharge_level(pq, 1) ≈ 0),
                "The `PqPoint` vectors should start at 0."
            )
        end

        inc_p = issorted(power_level(pq), lt= <=)
        inc_d = issorted(discharge_level(pq), lt= <=)
        @assert_or_log(
            inc_p & inc_d,
            "The `PqPoint` vectors must be increasing."
        )

        if (n_p ≥ 1) & (n_d ≥ 1)
            @assert_or_log(
                ((power_level(pq, 1) ≈ 0) & (power_level(pq, n_p) ≈ 1)) |
                ((discharge_level(pq, 1) ≈ 0) & (discharge_level(pq, n_d) ≈ 1)),
                "One of the `PqPoint` vectors should be from 0 to 1."
            )
        end

        # The slopes are only well defined for vectors of equal length with at least two
        # points and a strictly increasing discharge
        if (n_p == n_d) & (n_d ≥ 2) & inc_d
            slopes =
                (power_level(pq)[2:end] - power_level(pq)[1:end-1]) ./
                (discharge_level(pq)[2:end] - discharge_level(pq)[1:end-1])
            if isa(n, HydroGenerator)
                @assert_or_log(
                    issorted(slopes; rev = true),
                    "The `PqPoint` curve should be concave for generators."
                )
            else
                @assert_or_log(
                    issorted(slopes),
                    "The `PqPoint` curve should be convex for pumps."
                )
            end
        end
    end
    EMB.check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
end

"""
    EMB.check_node_data(n::EMB.Node, data::ScheduleConstraint, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Performs various checks on [`ScheduleConstraint`](@ref) data for all nodes.

## Checks
- The node is required to be a [`HydroReservoir`](@ref), [`HydroGate`](@ref),
  [`HydroGenerator`](@ref), or [`HydroPump`](@ref).
- The field `resource` is required to be either the water or the electricity resource if the
  node is a [`HydroUnit`](@ref).
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
    @assert_or_log(
        isa(n, HydroNode),
        "`ScheduleConstraint`s are only supported for `HydroReservoir`, `HydroGate`, " *
        "`HydroGenerator`, and `HydroPump` nodes."
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

This method checks that the [`AbstractBattery`](@ref) node is valid.

It reuses the standard checks of a `Storage` node through calling the function
[`EMB.check_node_default`](@extref EnergyModelsBase.check_node_default), but adds an
additional check on the data.

## Checks
- The `TimeProfile` of the field `capacity` in the type in the field `charge` is required to
  be non-negative.
- The `TimeProfile` of the field `capacity` in the type in the field `level` is required to
  be non-negative.
- The `TimeProfile` of the field `capacity` in the type in the field `discharge` is required
  to be non-negative.
- The `TimeProfile` of the field `opex_fixed` is required to be non-negative and accessible
  through a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex`](@extref EnergyModelsBase.check_fixed_opex) for the chosen
  composite type.
- The values of the field `input` must be in the range ``(0, 1]``.
- The values of the field `output` must be in the range ``(0, 1]``.
- The [`AbstractBatteryLife`](@ref) must follow the provided values as outlined in the
  function [`check_battery_life`](@ref).
"""
function EMB.check_node(n::AbstractBattery, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    EMB.check_node_default(n, 𝒯, modeltype, check_timeprofiles)
    has_input(n) && @assert_or_log(
        all(0 < inputs(n, p) ≤ 1 for p ∈ inputs(n)),
        "The values for the Dictionary `input` must be positive and less than or equal " *
        "to 1."
    )
    has_output(n) && @assert_or_log(
        all(0 < outputs(n, p) ≤ 1 for p ∈ outputs(n)),
        "The values for the Dictionary `output` must be positive and less than or equal " *
        "to 1."
    )
    check_battery_life(n, battery_life(n), 𝒯, modeltype, check_timeprofiles)
end

"""
    EMB.check_node(n::ReserveBattery, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that the [`ReserveBattery`](@ref) node is valid.

It reuses the standard checks of a `Storage` node through calling the function
[`EMB.check_node_default`](@extref EnergyModelsBase.check_node_default), but adds an
additional check on the data.

## Checks
- The `TimeProfile` of the field `capacity` in the type in the field `charge` is required to
  be non-negative.
- The `TimeProfile` of the field `capacity` in the type in the field `level` is required to
  be non-negative.
- The `TimeProfile` of the field `capacity` in the type in the field `discharge` is required
  to be non-negative.
- The `TimeProfile` of the field `opex_fixed` is required to be non-negative and accessible
  through a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex`](@extref EnergyModelsBase.check_fixed_opex) for the chosen
  composite type.
- The values of the field `input` must be in the range ``(0, 1]``.
- The values of the field `output` must be in the range ``(0, 1]``.
- The [`AbstractBatteryLife`](@ref) must follow the provided values as outlined in the
  function [`check_battery_life`](@ref).
- The resources in the array `reserve_up` cannot be part of the resources in the
  dictionaries `input` and `output`.
- The resources in the array `reserve_down` cannot be part of the resources in the
  dictionaries `input` and `output`.
"""
function EMB.check_node(n::ReserveBattery, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    EMB.check_node_default(n, 𝒯, modeltype, check_timeprofiles)
    has_input(n) && @assert_or_log(
        all(0 < inputs(n, p) ≤ 1 for p ∈ inputs(n)),
        "The values for the Dictionary `input` must be positive and less than or equal " *
        "to 1."
    )
    # The reserve resources are included in `outputs(n)` with a value of 0
    has_output(n) && @assert_or_log(
        all(0 < outputs(n, p) ≤ 1 for p ∈ keys(n.output)),
        "The values for the Dictionary `output` must be positive and less than or equal " *
        "to 1."
    )
    check_battery_life(n, battery_life(n), 𝒯, modeltype, check_timeprofiles)
    @assert_or_log(
        all(!haskey(n.input, p) for p ∈ reserve_up(n)),
        "The `reserve_up` resources cannot be in the `input` dictionary."
    )
    @assert_or_log(
        all(!haskey(n.output, p) for p ∈ reserve_up(n)),
        "The `reserve_up` resources cannot be in the `output` dictionary."
    )
    @assert_or_log(
        all(!haskey(n.input, p) for p ∈ reserve_down(n)),
        "The `reserve_down` resources cannot be in the `input` dictionary."
    )
    @assert_or_log(
        all(!haskey(n.output, p) for p ∈ reserve_down(n)),
        "The `reserve_down` resources cannot be in the `output` dictionary."
    )
end

"""
    check_battery_life(n::AbstractBattery, bat_life::AbstractBatteryLife, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    check_battery_life(n::AbstractBattery, bat_life::CycleLife, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Check that the included [`AbstractBatteryLife`](@ref) type of an [`AbstractBattery`](@ref)
follows the requirements of the type.

## Checks [`AbstractBatteryLife`](@ref)
- None.

## Checks [`CycleLife`](@ref)
- All fields must be positive.
- The value of the field `degradation` must be less than or equal to 1.
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

    sc_prof = stack_cost(bat_life)
    if (isa(sc_prof, StrategicProfile) || isa(sc_prof, StrategicStochasticProfile)) &&
        check_timeprofiles
        EMB.check_profile(:stack_cost, sc_prof, 𝒯; bool=false)
    end

    # Check for potential indexing problems
    message = "are not allowed for the field `stack_cost`."
    bool_sp = EMB.check_strategic_profile(sc_prof, message)

    # Check that the value is positive in all cases
    if bool_sp
        @assert_or_log(
            all(stack_cost(bat_life, t_inv) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ),
            "The values of the timeprofiles of the field `stack_cost` in the `CycleLife` " *
            "must be positive."
        )
    end
end
