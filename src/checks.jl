"""
    EMB.check_node(n::NonDisRES, 𝒯, modeltype::EMB.EnergyModel, check_timeprofiles::Bool)

This method checks that the *[`NonDisRES`](@ref NonDisRES_public)* node is valid.

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

This method checks that the *[`HydroStorage`](@ref HydroStorage_public)* node is valid.

## Checks
 - The value of the field `rate_cap` is required to be non-negative.
 - The value of the field `stor_cap` is required to be non-negative.
 - The value of the field `fixed_opex` is required to be non-negative and
   accessible through a `StrategicPeriod` as outlined in the function
   `check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`.
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
    # cap = capacity(n)

    # @assert_or_log(
    #     sum(cap.rate[t] < 0 for t ∈ 𝒯) == 0,
    #     "The production capacity in field `rate_cap` has to be non-negative."
    # )
    # @assert_or_log(
    #     sum(cap.level[t] < 0 for t ∈ 𝒯) == 0,
    #     "The storage capacity in field `stor_cap` has to be non-negative."
    # )
    # EMB.check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
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

    # @assert_or_log(
    #     sum(level_init(n, t) ≤ cap.level[t] for t ∈ 𝒯) == length(𝒯),
    #     "The initial level `level_init` has to be less or equal to the max storage capacity."
    # )
    # for t_inv ∈ 𝒯ᴵⁿᵛ

    #     t = first(t_inv)
    #     # Check that the reservoir isn't underfilled from the start.
    #     @assert_or_log(
    #         level_init(n, t_inv) + level_inflow(n, t) ≥ level_min(n, t) * cap.level[t],
    #         "The reservoir can't be underfilled from the start (" * string(t) * ").")
    # end

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
