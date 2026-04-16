
"""
    EMB.variables_node(m, 𝒩ⁿᵈʳ::Vector{<:AbstractNonDisRES}, 𝒯, modeltype::EnergyModel)

Creates the following additional variables for **ALL** [`AbstractNonDisRES`](@ref) nodes:
- `:curtailment[n, t]` is the unused energy within operational period t.
"""
function EMB.variables_node(m, 𝒩ⁿᵈʳ::Vector{<:AbstractNonDisRES}, 𝒯, modeltype::EnergyModel)
    @variable(m, curtailment[𝒩ⁿᵈʳ, 𝒯] ≥ 0)
end

"""
    EMB.variables_node(m, 𝒩::Vector{<:HydroStorage}, 𝒯, modeltype::EnergyModel)

Creates the following additional variables for **ALL** [`HydroStorage`](@ref) nodes:
- `:hydro_spill[n, t]` is the spilled energy from node `n` in operational period `t` without
  pproducing energy. It is included to avoid infeasible models.
"""
function EMB.variables_node(m, 𝒩::Vector{<:HydroStorage}, 𝒯, modeltype::EnergyModel)
    @variable(m, hydro_spill[𝒩, 𝒯] ≥ 0)
end

"""
    EMB.create_node(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EnergyModel)

Sets all constraints for the regulated hydro storage node.

It differs from the function for a standard [`RefStorage`](@extref EnergyModelsBase.RefStorage)
node through not calling the function
[`constraints_flow_out`](@extref EnergyModelsBase.constraints_flow_out) but incorporating
the outflow constraints directly.

# Called constraint functions
- [`constraints_level`](@extref EnergyModelsBase.constraints_level),
- [`constraints_data`](@extref EnergyModelsBase.constraints_data) for all `node_data(n)`,
- [`constraints_flow_in`](@extref EnergyModelsBase.constraints_flow_in),
- [`constraints_capacity`](@extref EnergyModelsBase.constraints_capacity),
- [`constraints_opex_fixed`](@extref EnergyModelsBase.constraints_opex_fixed), and
- [`constraints_opex_var`](@extref EnergyModelsBase.constraints_opex_var).
"""
function EMB.create_node(m, n::HydroStorage, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    p_stor = EMB.storage_resource(n)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Energy balance constraints for stored electricity.
    constraints_level(m, n, 𝒯, 𝒫, modeltype)

    # Iterate through all data and set up the constraints corresponding to the data
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

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
    # Create the variables
    @variable(m, gate_penalty_up[
        n ∈ 𝒩,
        t ∈ 𝒯,
        inputs(n);
        any([has_penalty_up(c, t) for c ∈ constraint_data(n)])
    ] ≥ 0)
    @variable(m, gate_penalty_down[
        n ∈ 𝒩,
        t ∈ 𝒯,
        inputs(n);
        any([has_penalty_down(c, t) for c ∈ constraint_data(n)])
    ] ≥ 0)
end

"""
    EMB.variables_node(m, 𝒩::Vector{<:HydroReservoir}, 𝒯, modeltype::EnergyModel)

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
function EMB.variables_node(m, 𝒩::Vector{<:HydroReservoir}, 𝒯, modeltype::EnergyModel)
    # Create the variables
    @variable(m, rsv_penalty_up[
        n ∈ 𝒩,
        t ∈ 𝒯,
        [storage_resource(n)];
        any([has_penalty_up(c, t) for c ∈ constraint_data(n)])
    ] ≥ 0)
    @variable(m, rsv_penalty_down[
        n ∈ 𝒩,
        t ∈ 𝒯,
        [storage_resource(n)];
        any([has_penalty_down(c, t) for c ∈ constraint_data(n)])
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
    # Create the variable for the discharge segment
    @variable(m, discharge_segment[
        n ∈ 𝒩,
        𝒯,
        discharge_segments(pq_curve(n))
    ] ≥ 0)

    # Add discharge/production constraint penalty variables
    @variable(m, gen_penalty_up[
        n ∈ 𝒩,
        t ∈ 𝒯,
        p ∈ [water_resource(n), electricity_resource(n)];
        any([has_penalty_up(c, t, p) for c ∈ constraint_data(n)])
    ] ≥ 0)

    @variable(m, gen_penalty_down[
        n ∈ 𝒩,
        t ∈ 𝒯,
        p ∈ [water_resource(n), electricity_resource(n)];
        any([has_penalty_down(c, t, p) for c ∈ constraint_data(n)])
    ] ≥ 0)
end

"""
    EMB.variables_node(m, 𝒩::Vector{<:AbstractBattery}, 𝒯, modeltype::EnergyModel)

Creates the following additional variables for **ALL** [`AbstractBattery`](@ref) nodes
- `bat_prev_use[n, t]` is the accumulated charge effect of an `AbstractBattery` up
  to operational period `t`.
- `bat_prev_use_sp[n, t_inv]` is the accumulated charge effect of an `AbstractBattery` up
  to investment period `t_inv`.
- `bat_use_sp[n, t_inv]` is the accummulated charge effect of an `AbstractBattery` in
  investment period `t_inv`.
- `bat_use_rp[n, t_rp]` is the accummulated charge effect of an `AbstractBattery` in
  representative period `t_rp`. It is only declared if the `TimeStructure` includes
  `RepresentativePeriods`.
- `bat_stack_replace_b[n, t_inv]` is a binary variable for identification of battery
  battery stack replacement. Stack replacement occurs before the first operational period of a
  strategic period. It is only declared for batterys which utilize an
  [`AbstractBatteryLife`](@ref) that includes degradation.
"""
function EMB.variables_node(m, 𝒩::Vector{<:AbstractBattery}, 𝒯, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒩ᶜˡ = filter(has_degradation, 𝒩)

    # Variables for degredation
    @variable(m, bat_prev_use[𝒩, 𝒯] ≥ 0)
    @variable(m, bat_prev_use_sp[𝒩, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, bat_use_sp[𝒩, 𝒯ᴵⁿᵛ] ≥ 0)
    if 𝒯 isa TwoLevel{S,T,U} where {S,T,U<:RepresentativePeriods}
        𝒯ʳᵖ = repr_periods(𝒯)
        @variable(m, bat_use_rp[𝒩, 𝒯ʳᵖ])
    end
    @variable(m, bat_stack_replace_b[𝒩ᶜˡ, 𝒯ᴵⁿᵛ], Bin)
end

"""
    EMB.variables_node(m, 𝒩::Vector{<:ReserveBattery}, 𝒯, modeltype::EnergyModel)

Creates the following additional variables for **ALL** [`ReserveBattery`](@ref) nodes
- `bat_res_up[n, t]` is the upwards reserve of battery storage `n` in operational period `t`.
- `bat_res_down[n, t]` is the upwards reserve of battery of storage `n` in operational
  period `t`.
"""
function EMB.variables_node(m, 𝒩::Vector{<:ReserveBattery}, 𝒯, modeltype::EnergyModel)
    @variable(m, bat_res_up[𝒩, 𝒯] ≥ 0)
    @variable(m, bat_res_down[𝒩, 𝒯] ≥ 0)
end


"""
    EMB.create_node(m, n::AbstractBattery, 𝒯, 𝒫, modeltype::EnergyModel)

Set all constraints for a `AbstractBattery`. Can serve as fallback option for all unspecified
subtypes of `AbstractBattery`. It differs from the function for a standard `Storage` node
through calling the constraint function [`constraints_usage`](@ref) for calculating the
cycles of the node.

# Called constraint functions
- [`constraints_level`](@extref EnergyModelsBase.constraints_level),
- [`constraints_usage`](@ref),
- [`constraints_reserve`](@ref),
- [`constraints_data`](@extref EnergyModelsBase.constraints_data) for all `node_data(n)`,
- [`constraints_flow_in`](@extref EnergyModelsBase.constraints_flow_in),
- [`constraints_flow_out`](@extref EnergyModelsBase.constraints_flow_out),
- [`constraints_capacity`](@extref EnergyModelsBase.constraints_capacity),
- [`constraints_opex_fixed`](@extref EnergyModelsBase.constraints_opex_fixed), and
- [`constraints_opex_var`](@extref EnergyModelsBase.constraints_opex_var).
"""
function EMB.create_node(m, n::AbstractBattery, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Mass/energy balance constraints for stored energy carrier
    constraints_level(m, n, 𝒯, 𝒫, modeltype)

    # Usage constraints for the battery
    constraints_usage(m, n, 𝒯, modeltype)

    # Reserve constraints for the battery
    constraints_reserve(m, n, 𝒯, modeltype)

    # Iterate through all data and set up the constraints corresponding to the data
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

    # Call of the function for the inlet flow to and outlet flow from the `Storage` node
    constraints_flow_in(m, n, 𝒯, modeltype)
    constraints_flow_out(m, n, 𝒯, modeltype)

    # Call of the function for limiting the capacity to the maximum installed capacity
    constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end
