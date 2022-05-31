using GLPK
using JuMP
using Test

using EnergyModelsBase
using TimeStructures
using RenewableProducers


"""
    EMB.check_node(n::NonDisRES, 𝒯, modeltype::EMB.EnergyModel)
    
This method checks that the [`NonDisRES`](@ref) node is valid. 

## Checks
 - The field `n.Profile` is required to be in the range ``[0, 1]`` for all time steps ``t ∈ \\mathcal{T}``.
"""
function EMB.check_node(n::NonDisRES, 𝒯, modeltype::EMB.OperationalModel) # TODO: make into EnergyModel
    
    @assert_or_log sum(n.Profile[t] ≤ 1 for t ∈ 𝒯) == length(𝒯) "The profile field must be less or equalt to 1."
    @assert_or_log sum(n.Profile[t] ≥ 0 for t ∈ 𝒯) == length(𝒯) "The profile field must be non-negative."
end


"""
    EMB.check_node(n::RegHydroStor, 𝒯, modeltype::EMB.EnergyModel)

This method checks that the [`RegHydroStor`](@ref) node is valid.  """
function EMB.check_node(n::RegHydroStor, 𝒯, modeltype::EMB.OperationalModel) # TODO: make into EnergyModel
    
    @assert_or_log length(n.Output) == 1 "Only one resource can be stored, so only this one can flow out."
    
    for v in values(n.Output)
        @assert_or_log v <= 1 "The value of the stored resource in n.output has to be less than or equal to 1."
    end

    for v in values(n.Input)
        @assert_or_log v <= 1 "The values of the input variables has to be less than or equal to 1."
        @assert_or_log v >= 0 "The values of the input variables has to be non-negative."
    end

    @assert_or_log sum(n.Level_init[t] <= n.Stor_cap[t] for t ∈ 𝒯) == length(𝒯) "The initial reservoir has to be less or equal to the max storage capacity."

    for t_inv in strategic_periods(𝒯)
        t = first_operational(t_inv)
        # Check that the reservoir doesn't overfill in the first operational period of an investment period.
        @assert_or_log n.Level_init[t_inv] + n.Level_inflow[t] - n.Rate_cap[t] <= n.Stor_cap[t] "The dam must have the installed production capacity to handle the inflow (" * string(t) * ")."

        # Check that the reservoir isn't underfilled from the start.
        @assert_or_log n.Level_init[t_inv] + n.Level_inflow[t] >= n.Level_min[t_inv] * n.Stor_cap[t] "The reservoir can't be underfilled from the start (" * string(t) * ")."
    end

    @assert_or_log sum(n.Level_init[t] < 0 for t ∈ 𝒯) == 0 "The Level_init can not be negative."

    @assert_or_log sum(n.Rate_cap[t] < 0 for t ∈ 𝒯) == 0 "The production capacity n.Rate_cap has to be non-negative."

    # Level_min
    @assert_or_log sum(n.Level_min[t] < 0 for t ∈ 𝒯) == 0 "The Level_min can not be negative."
    @assert_or_log sum(n.Level_min[t] > 1 for t ∈ 𝒯) == 0 "The Level_min can not be larger than 1."

end
