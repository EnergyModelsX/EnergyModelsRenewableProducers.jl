"""
    EMB.check_node(n::NonDisRES, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)

This method checks that the *[`NonDisRES`](@ref)* node is valid.

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
function EMB.check_node(n::NonDisRES, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        sum(capacity(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The capacity must be non-negative."
    )
    EMB.check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
    @assert_or_log(
        sum(outputs(n, p) ≥ 0 for p ∈ outputs(n)) == length(outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    @assert_or_log(
        sum(profile(n, t) ≤ 1 for t ∈ 𝒯) == length(𝒯),
        "The profile field must be less or equal to 1."
    )
    @assert_or_log(
        sum(profile(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The profile field must be non-negative."
    )
end

"""
    EMB.check_node(n::HydroStorage, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)

This method checks that the *[`HydroStorage`](@ref)* node is valid.

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
 - The value of the field `output` is required to be smaller or equal to 1.
 - The value of the field `input` is required to be in the range ``[0, 1]``.
 - The value of the field `level_init` is required to be in the range
   ``[level\\_min, 1] \\cdot stor\\_cap(t)`` for all time steps ``t ∈ \\mathcal{T}``.
 - The value of the field `level_init` is required to be in the range ``[0, 1]``.
 - The value of the field `level_min` is required to be in the range ``[0, 1]``.
"""
function EMB.check_node(n::HydroStorage, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    par_charge = charge(n)
    par_level = level(n)
    par_discharge = discharge(n)

    if isa(par_charge, EMB.UnionCapacity)
        @assert_or_log(
            sum(capacity(par_charge, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
            "The charge capacity must be non-negative."
        )
    end
    if isa(par_charge, EMB.UnionOpexFixed)
        EMB.check_fixed_opex(par_charge, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    @assert_or_log(
        sum(capacity(par_level, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The level capacity must be non-negative."
    )
    if isa(par_level, EMB.UnionOpexFixed)
        EMB.check_fixed_opex(par_level, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    if isa(par_discharge, EMB.UnionCapacity)
        @assert_or_log(
            sum(capacity(par_discharge, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
            "The charge capacity must be non-negative."
        )
    end
    if isa(par_discharge, EMB.UnionOpexFixed)
        EMB.check_fixed_opex(par_discharge, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end

    @assert_or_log(
        length(outputs(n)) == 1,
        "Only one resource can be stored, so only this one can flow out."
    )

    for v ∈ values(n.output)
        @assert_or_log(
            v ≤ 1,
            "The value of the `output` resource has to be less than or equal to 1."
        )
        @assert_or_log(
            v ≥ 0,
            "The value of the `output` resource has to be non-negative."
        )
    end

    for v ∈ values(n.input)
        @assert_or_log(
            v ≤ 1,
            "The values of the input variables have to be less than or equal to 1."
        )
        @assert_or_log(
            v ≥ 0,
            "The values of the input variables have to be non-negative."
        )
    end

    @assert_or_log(
        sum(level_init(n, t) ≤ capacity(par_level, t) for t ∈ 𝒯) == length(𝒯),
        "The initial level `level_init` has to be less or equal to the max storage capacity."
    )
    for t_inv ∈ 𝒯ᴵⁿᵛ
        t = first(t_inv)
        # Check that the reservoir isn't underfilled from the start.
        @assert_or_log(
            level_init(n, t_inv) + level_inflow(n, t) ≥ level_min(n, t) * capacity(par_level, t),
            "The reservoir can't be underfilled from the start (" * string(t) * ").")
    end

    @assert_or_log(
        sum(level_init(n, t) < 0 for t ∈ 𝒯) == 0,
        "The field `level_init` can not be negative."
    )

    # level_min
    @assert_or_log(
        sum(level_min(n, t) < 0 for t ∈ 𝒯) == 0,
        "The field `level_min` can not be negative."
    )
    @assert_or_log(
        sum(level_min(n, t) > 1 for t ∈ 𝒯) == 0,
        "The field `level_min` can not be larger than 1."
    )
end

"""
    EMB.check_node(n::HydroReservoir, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)

This method checks that the [`HydroReservoir`](@ref) node is valid.

## Checks
- The `TimeProfile` of the `capacity` of the `HydroReservoir` `level` is required
  to be non-negative.
"""
function EMB.check_node(n::HydroReservoir, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    par_level = level(n)

    if isa(par_level, EMB.UnionCapacity)
        @assert_or_log(
            all(capacity(par_level, t) ≥ 0 for t ∈ 𝒯),
            "The volume capacity has to be non-negative."
        )
    end
end

"""
    EMB.check_node(n::HydroGate, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)

This method checks that the *[`HydroGate`](@ref)* node is valid.

## Checks
 - The field `cap` is required to be non-negative.
"""
function EMB.check_node(n::HydroGate, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )
end

"""
    EMB.check_node(n::HydroUnit, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)

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
        sum(capacity(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
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
    EMB.check_node_data(n::EMB.Node, data::Constraint, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Performs various checks on [`Constraint`](@ref) data for all nodes.

## Checks
- The value of constraints are required to be in the range ``[0, 1]`` for all time steps
  ``t ∈ \\mathcal{T}``.
"""
function EMB.check_node_data(
    n::EMB.Node,
    data::Constraint,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)

    @assert_or_log(
        all(0 ≤ value(data, t) ≤ 1 for t ∈ 𝒯),
        "The relative constraint value must be between 0 and 1."
    )
end
