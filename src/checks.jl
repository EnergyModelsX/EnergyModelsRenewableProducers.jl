using EnergyModelsBase
using Test
using TimeStructures
using JuMP
using GLPK
using RenewableProducers

const EMB = EnergyModelsBase
const RP = RenewableProducers


" This method checks that the RegHydroStor node is valid. "
function EMB.check_node(n::RP.RegHydroStor, 𝒯)
    @assert_or_log length(n.output) == 1 "Only one resource can be stored, so only this one can flow out."
    
    for v in values(n.output)
        @assert_or_log v == 1 "The value of the stored resource in n.output has to be 1."
    end

    for v in values(n.input)
        @assert_or_log v <= 1 "The values of the input variables has to be less than or equal to 1."
    end

    @assert_or_log n.init_reservoir <= n.cap_storage "The initial reservoir has to be less or equal to the max storage capacity."

    for t_inv in strategic_periods(𝒯)
        t = first_operational(t_inv)
        # Check that the reservoir doesn't overfill in the first operational period of an investment period.
        @assert_or_log n.init_reservoir + n.inflow[t] - n.capacity[t] <= n.cap_storage "The dam must have the installed production capacity to handle the inflow (" * string(t) * ")."

        # Check that the reservoir isn't underfilled from the start.
        @assert_or_log n.init_reservoir + n.inflow[t] >= n.min_level * n.cap_storage "The reservoir can't be underfilled from the start."
    end

    @assert_or_log sum(n.capacity[t] < 0 for t ∈ 𝒯) == 0 "The production capacity n.capacity has to be non-negative."
end
