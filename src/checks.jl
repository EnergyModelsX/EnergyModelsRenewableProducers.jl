using EnergyModelsBase
using Test
using TimeStructures
using JuMP
using GLPK
using RenewableProducers

const RP = RenewableProducers


" This method checks that the RegHydroStor node is valid. "
function EMB.check_node(n::RP.RegHydroStor, 𝒯, modeltype::EMB.OperationalModel)
    
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
