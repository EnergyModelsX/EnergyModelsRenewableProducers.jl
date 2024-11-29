"""
    EMB.check_node_data(n::Union{HydroReservoir,HydroUnit,HydroGate}, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel, check_timeprofiles::Bool)

As [`HydroReservoir`](@ref), [`HydroUnit`](@ref), and [`HydroGate`](@ref) nodes cannot
utilize investments at the time being, a separate function is required

## Checks
- No investment data is allowed
"""
function EMB.check_node_data(
    n::Union{HydroReservoir,EMRP.HydroUnit,HydroGate},
    data::InvestmentData,
    𝒯,
    modeltype::AbstractInvestmentModel,
    check_timeprofiles::Bool,
)

    @assert_or_log(
        !has_investment(n),
        "`InvestmentData` is not allowed for $(typeof(n)) nodes."
    )
end
