"""
    EMB.check_node(n::NonDisRES, 𝒯, modeltype::EMB.EnergyModel)

This method checks that the [`NonDisRES`](@ref) node is valid.

## Checks
 - The field `n.Profile` is required to be in the range ``[0, 1]`` for all time steps ``t ∈ \\mathcal{T}``.
"""
function EMB.check_node(n::NonDisRES, 𝒯, modeltype::OperationalModel)
    @assert_or_log sum(profile(n, t) ≤ 1 for t ∈ 𝒯) == length(𝒯) "The profile field must be less or equal to 1."
    @assert_or_log sum(profile(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯) "The profile field must be non-negative."
end

"""
    EMB.check_node(n::RegHydroStor, 𝒯, modeltype::EMB.EnergyModel)

This method checks that the [`RegHydroStor`](@ref) node is valid.
"""
function EMB.check_node(n::HydroStorage, 𝒯, modeltype::OperationalModel)
    @assert_or_log length(outputs(n)) == 1 "Only one resource can be stored, so only this one can flow out."
    cap = capacity(n)

    for v ∈ values(n.output)
        @assert_or_log v <= 1 "The value of the stored resource in n.output has to be less than or equal to 1."
    end

    for v ∈ values(n.input)
        @assert_or_log v <= 1 "The values of the input variables has to be less than or equal to 1."
        @assert_or_log v >= 0 "The values of the input variables has to be non-negative."
    end

    @assert_or_log sum(level_init(n, t) <= cap.level[t] for t ∈ 𝒯) == length(𝒯) "The initial reservoir has to be less or equal to the max storage capacity."

    for t_inv ∈ strategic_periods(𝒯)
        for t ∈ t_inv
            @assert_or_log level_init(n, t_inv) <= cap.level[t] "The initial level can not be greater than the dam capacity (" *
                                                                string(t) *
                                                                ")."
        end

        t = first(t_inv)
        # Check that the reservoir isn't underfilled from the start.
        @assert_or_log level_init(n, t_inv) + level_inflow(n, t) >=
                       level_min(n, t) * cap.level[t] "The reservoir can't be underfilled from the start (" *
                                                      string(t) *
                                                      ")."
    end

    @assert_or_log sum(level_init(n, t) < 0 for t ∈ 𝒯) == 0 "The level_init can not be negative."

    @assert_or_log sum(cap.rate[t] < 0 for t ∈ 𝒯) == 0 "The production capacity n.rate_cap has to be non-negative."

    # level_min
    @assert_or_log sum(level_min(n, t) < 0 for t ∈ 𝒯) == 0 "The level_min can not be negative."
    @assert_or_log sum(level_min(n, t) > 1 for t ∈ 𝒯) == 0 "The level_min can not be larger than 1."
end
