using EnergyModelsBase
using Test
using TimeStructures
using JuMP
using GLPK
using RenewableProducers

const RP = RenewableProducers


" This method checks that the RegHydroStor node is valid. "
function EMB.check_node(n::RP.RegHydroStor, 𝒯, modeltype::EMB.OperationalModel)
    
    @assert_or_log length(n.output) == 1 "Only one resource can be stored, so only this one can flow out."
    
    for v in values(n.output)
        @assert_or_log v <= 1 "The value of the stored resource in n.output has to be less than or equal to 1."
    end

    for v in values(n.input)
        @assert_or_log v <= 1 "The values of the input variables has to be less than or equal to 1."
        @assert_or_log v >= 0 "The values of the input variables has to be non-negative."
    end

    @assert_or_log sum(n.init_reservoir[t] <= n.cap_storage[t] for t ∈ 𝒯) == length(𝒯) "The initial reservoir has to be less or equal to the max storage capacity."

    for t_inv in strategic_periods(𝒯)
        t = first_operational(t_inv)
        # Check that the reservoir doesn't overfill in the first operational period of an investment period.
        @assert_or_log n.init_reservoir[t_inv] + n.inflow[t] - n.capacity[t] <= n.cap_storage[t] "The dam must have the installed production capacity to handle the inflow (" * string(t) * ")."

        # Check that the reservoir isn't underfilled from the start.
        @assert_or_log n.init_reservoir[t_inv] + n.inflow[t] >= n.min_level[t_inv] * n.cap_storage[t] "The reservoir can't be underfilled from the start (" * string(t) * ")."
    end

    @assert_or_log sum(n.init_reservoir[t] < 0 for t ∈ 𝒯) == 0 "The init_reservoir can not be negative."

    @assert_or_log sum(n.capacity[t] < 0 for t ∈ 𝒯) == 0 "The production capacity n.capacity has to be non-negative."

    # min_level
    @assert_or_log sum(n.min_level[t] < 0 for t ∈ 𝒯) == 0 "The min_level can not be negative."
    @assert_or_log sum(n.min_level[t] > 1 for t ∈ 𝒯) == 0 "The min_level can not be larger than 1."

end
