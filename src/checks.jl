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

This method checks that the *[`HydroReservoir`](@ref)* node is valid.

## Checks
 - The `TimeProfile` of the field `capacity` in the type in the field `vol` is required
  to be non-negative if the chosen composite type has the field `capacity`.
 - The value of the field `vol_init` is required to be in the range
   ``[0, vol.capacity(t)]`` at the first time step of strategic periods.
 - The value of the field `vol_init` is required to be in the range
   ``[vol_min(t), vol_max(t)]`` at the first time step of strategic periods.
 - The value of the fields `vol_min` and `vol_max` are required to be in the range
    ``[0, vol.capacity(t)]`` for all time steps ``t ∈ \\mathcal{T}``.
- The value of the field `vol_min` is required to be less than or equal to the field `vol_max`
    for all time steps ``t ∈ \\mathcal{T}``.
 - The field `output` can only include a single `Resource`.
 - The value of the field `output` is required to be smaller or equal to 1.
 - The value of the field `output` is required to be non-negative.
 - The field `input` can only include a single `Resource`.
 - The value of the field `input` is required to be smaller or equal to 1.
 - The value of the field `input` is required to be non-negative.
"""
function EMB.check_node(n::HydroReservoir, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    par_level = level(n)

    if isa(par_level, EMB.UnionCapacity)
        @assert_or_log(
            sum(capacity(par_level, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
            "The volume capacity has to be non-negative."
        )
    end
    @assert_or_log(
        0 ≤ vol_init(n, first(𝒯ᴵⁿᵛ)) ≤ capacity(par_level, first(𝒯ᴵⁿᵛ)),
        "The initial volume must be between the minimum and the capacity volume."
    )
    # if isa(n.vol_constraint,
    #     Union{MaxConstraint, MinMaxConstraint, MaxPenaltyConstraint, MinMaxPenaltyConstraint})
    #     @assert_or_log(
    #         vol_init(n, first(𝒯)) ≤ n.vol_constraint.max[first(𝒯)],
    #         "The initial volume must be less than or equal to the maximum volume."
    #     )
    #     @assert_or_log(
    #         sum(n.vol_constraint.max[t] ≤ capacity(par_level, t) for t ∈ 𝒯) == length(𝒯),
    #         "The maximum volume must be less than or equal to the volume capacity."
    #     )
    # end
    # if isa(n.vol_constraint,
    #     Union{MinConstraint, MinMaxConstraint, MinPenaltyConstraint, MinMaxPenaltyConstraint})
    #     @assert_or_log(
    #         vol_init(n, first(𝒯)) ≥ n.vol_constraint.min[first(𝒯)],
    #         "The initial volume must be greater than or equal to the minimum volume."
    #     )
    #     @assert_or_log(
    #         sum(n.vol_constraint.min[t] ≤ capacity(par_level, t) for t ∈ 𝒯) == length(𝒯),
    #         "The minimum volume must be less than or equal to the volume capacity."
    #     )
    # end
    # if isa(n.vol_constraint, Union{MinMaxConstraint, MinMaxPenaltyConstraint})
    #     @assert_or_log(
    #         sum(n.vol_constraint.min[t] ≤ n.vol_constraint.max[t] for t ∈ 𝒯) == length(𝒯),
    #         "The minimum volume must be less than or equal to the maximum volume."
    #     )
    # end

    # EMB.check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
    @assert_or_log(
        length(outputs(n)) == 1,
        "Only one resource can be stored, so only this one can flow out."
    )
    @assert_or_log(
        sum(0 ≤ outputs(n, p) ≤ 1 for p ∈ outputs(n)) == length(outputs(n)),
        "The values for the Dictionary `output` must be in the range [0, 1]."
    )

    @assert_or_log(
        length(inputs(n)) == 1,
        "Only one resource can be stored, so only one resource can flow in."
    )

    @assert_or_log(
        sum(0 ≤ inputs(n, p) ≤ 1 for p ∈ inputs(n)) == length(inputs(n)),
        "The values for the Dictionary `inputs` must be in the range [0, 1]."
    )
end

"""

    EMB.check_node(n::HydroGenerator, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)

This method checks that the *[`HydroGenerator`](@ref HydroGenerator_public)* node is valid.

## Checks
 - The field `cap` is required to be non-negative.
 - The values of the dictionary `input` are required to be non-negative.
 - The values of the dictionary `output` are required to be non-negative.
 - The value of the field `fixed_opex` is required to be non-negative and
   accessible through a `StrategicPeriod` as outlined in the function
   `check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`.
- The field `pq_curve` is required to be `nothing` or a dict with values for two resources \
in the form of two vectors of equal size with non-negative values.
- the field `η` must be nothing if the field `pq_curve` is nothing.
"""
function EMB.check_node(n::HydroGenerator, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        sum(capacity(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The capacity must be non-negative."
    )

    @assert_or_log(
        sum(inputs(n, p) ≥ 0 for p ∈ inputs(n)) == length(inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )

    @assert_or_log(
        sum(outputs(n, p) ≥ 0 for p ∈ outputs(n)) == length(outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )

    if !isnothing(pq_curve(n))
        @assert_or_log(

            length(pq_curve(n)) == 2,
            "There must be 2 resources given in the Dictionary `pq_curve`."
        )

        for p ∈ pq_curve(n)
            values = pq_curve(n, p)
            @assert_or_log(
                sum(v < 0 for v in values)==0,
                "All the values in Dictionary `pq_curve` must be non-negative."
                 )

            @assert_or_log(
            length(pq_curve(n, p)) == length(pq_curve(n, pq_curve(n)[1])),
            "Equal number of values must be provided for all resources in the Dictionary `pq_curve`."
            )
        end


    else
        @assert_or_log(
            (isempty(efficiency(n))),
             "The efficiency `η` must be empty if the `pq_curve` is `nothing`."
             )

    end

   #TODO add test for concave PQ-curve


    EMB.check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
end
