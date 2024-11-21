
"""
    EMB.variables_node(m, 𝒩ⁿᵈʳ::Vector{<:AbstractNonDisRES}, 𝒯, modeltype::EnergyModel)

Create the optimization variable `:curtailment` for every [`AbstractNonDisRES`](@ref) node.
This method is called from `EnergyModelsBase.jl`.
"""
function EMB.variables_node(m, 𝒩ⁿᵈʳ::Vector{<:AbstractNonDisRES}, 𝒯, modeltype::EnergyModel)
    @variable(m, curtailment[𝒩ⁿᵈʳ, 𝒯] ≥ 0)
end

"""
    EMB.variables_node(m, 𝒩::Vector{<:HydroStorage}, 𝒯, modeltype::EnergyModel)

Create the optimization variable `:hydro_spill` for every HydroStorage node. This variable
enables hydro storage nodes to spill water from the reservoir without producing energy.
Wihtout this slack variable, parameters with too much inflow would else lead to an
infeasible model. """
function EMB.variables_node(m, 𝒩::Vector{<:HydroStorage}, 𝒯, modeltype::EnergyModel)
    @variable(m, hydro_spill[𝒩, 𝒯] ≥ 0)
end

"""
    EMB.create_node(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EnergyModel)

Sets all constraints for the regulated hydro storage node.
"""
function EMB.create_node(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    p_stor = EMB.storage_resource(n)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Energy balance constraints for stored electricity.
    constraints_level(m, n, 𝒯, 𝒫, modeltype)

    # Call of the function for the inlet flow to the `HydroStorage` node
    constraints_flow_in(m, n, 𝒯, modeltype)

    # The flow_out is equal to the production stor_rate_use.
    @constraint(
        m,
        [t ∈ 𝒯],
        m[:flow_out][n, t, p_stor] == m[:stor_discharge_use][n, t] * outputs(n, p_stor)
    )

    # Can not produce more energy than what is availbable in the reservoir.
    @constraint(m, [t ∈ 𝒯], m[:stor_discharge_use][n, t] ≤ m[:stor_level][n, t])

    # Iterate through all data and set up the constraints corresponding to the data
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

    # Call of the function for limiting the capacity to the maximum installed capacity
    constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end

"""
    EMB.variables_node(m, 𝒩::Vector{HydroGate}, 𝒯, modeltype::EnergyModel)

Creates the following additional variables for **ALL** [`HydroGate`](@ref) nodes that have
additional constraints through [`ScheduleConstraint`](@ref):
- `gate_penalty_up[n, t, p]` is the *up* penalty variable of hydro gate `n` in operational
  period `t` for resource `p`.
- `gate_penalty_down[n, t, p]` is the *down* penalty variable of hydro gate `n` in operational
  period `t` for resource `p`.

These variables enable `HydroGate` nodes to penalize a violation of the discharge constraint
instead of providing a strict upper bound. They hence transform the constraint to a soft
constraint. Without these penalty variables, too strict discharge restrictions may cause an
infeasible model.
"""
function EMB.variables_node(m, 𝒩::Vector{HydroGate}, 𝒯, modeltype::EnergyModel)

    @variable(m, gate_penalty_up[
        n ∈ 𝒩,
        t ∈ 𝒯,
        p ∈ inputs(n);
        any([has_penalty_up(c, t) for c in constraint_data(n)])
    ] ≥ 0)
    @variable(m, gate_penalty_down[
        n ∈ 𝒩,
        t ∈ 𝒯,
        p ∈ inputs(n);
        any([has_penalty_down(c, t) for c in constraint_data(n)])
    ] ≥ 0)
end

"""
    EMB.variables_node(m, 𝒩::Vector{HydroReservoir{T}}, 𝒯, modeltype::EnergyModel) where \
    {T <: EMB.StorageBehavior}


Creates the following additional variables for **ALL** [`HydroReservoir`](@ref) nodes that
have additional constraints through [`ScheduleConstraint`](@ref):
- `rsv_penalty_up[n, t, p]` is the *up* penalty variable of hydro reservoir `n` in
  operational period `t` for resource `p`.
- `rsv_penalty_down[n, t, p]` is the *down* penalty variable of hydro reservoir `n` in
  operational period `t` for resource `p`.

These variables enable `HydroReservoir` nodes to penalize a violation of the volume constraint
instead of providing a strict bound. They hence transform the constraint to a soft
constraint. Without these penalty variables, too strict volume restrictions may cause an
infeasible model.
"""
function EMB.variables_node(m, 𝒩::Vector{<:HydroReservoir{T}}, 𝒯,
    modeltype::EnergyModel) where {T <: EMB.StorageBehavior}

    @variable(m, rsv_penalty_up[
        n ∈ 𝒩,
        t ∈ 𝒯,
        p ∈ [storage_resource(n)];
        any([has_penalty_up(c, t) for c in constraint_data(n)])
    ] ≥ 0)
    @variable(m, rsv_penalty_down[
        n ∈ 𝒩,
        t ∈ 𝒯,
        p ∈ [storage_resource(n)];
        any([has_penalty_down(c, t) for c in constraint_data(n)])
    ] ≥ 0)
end


"""
    EMB.variables_node(m, 𝒩::Vector{:<HydroUnit}, 𝒯, modeltype::EnergyModel)

Creates the following additional variables for **ALL** [`HydroUnit`](@ref) nodes that
have additional constraints through [`ScheduleConstraint`](@ref):
- `gen_penalty_up[n, t, p]` is the *up* penalty variable of hydro unit `n` in
  operational period `t` for resource `p`.
- `rsv_penalty_down[n, t, p]` is the *down* penalty variable of hydro unit `n` in
  operational period `t` for resource `p`.
- `discharge_segment[n, t, q]` is the discharge segment variable of hydro unit `n` in
  operational period `t` for discharge segment `q`
  The capacity of the `discharge_segment`s sums up to the total discharge capacity.

The first two variables enable `HydroUnit` nodes to penalize a violation of the
generation/pumping constraints instead of providing a strict bound. They hence transform the
constraint to a soft constraint. Without these penalty variables, too strict generation/pumping
constraints may cause an infeasible model.
"""
function EMB.variables_node(m, 𝒩::Vector{<:HydroUnit}, 𝒯, modeltype::EnergyModel)
    @variable(m, discharge_segment[
        n ∈ 𝒩,
        t ∈ 𝒯,
        q ∈ discharge_segments(pq_curve(n))
    ] ≥ 0)

    # Add discharge/production constraint penalty variables
    @variable(m, gen_penalty_up[
        n ∈ 𝒩,
        t ∈ 𝒯,
        p ∈ [water_resource(n), electricity_resource(n)];
        any([has_penalty_up(c, t, p) for c in constraint_data(n)])
    ] ≥ 0)

    @variable(m, gen_penalty_down[
        n ∈ 𝒩,
        t ∈ 𝒯,
        p ∈ [water_resource(n), electricity_resource(n)];
        any([has_penalty_down(c, t, p) for c in constraint_data(n)])
    ] ≥ 0)
end

"""
    EMB.variables_node(m, 𝒩::Vector{<:ReserveBattery}, 𝒯, modeltype::EnergyModel)

Declaration of reserve variables for [`ReserveBattery`](@ref) nodes.
The following reserve variables are declared:

- `bat_res_up[n, t]` is the upwards reserve of battery storage `n` in operational period `t`.
- `bat_res_down[n, t]` is the upwards reserve of battery of storage `n` in operational
  period `t`.
"""
function EMB.variables_node(m, 𝒩::Vector{<:ReserveBattery}, 𝒯, modeltype::EnergyModel)
    @variable(m, bat_res_up[𝒩, 𝒯] ≥ 0)
    @variable(m, bat_res_down[𝒩, 𝒯] ≥ 0)
end
