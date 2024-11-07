using TimeStruct
using Interpolations

"""
    struct WindPowerPlant

# Fields:
- power_curve: Lookup table, gives power (relative to capacity) for given 
               wind speed (1st dim) and wind direction (2nd dim)
- turbine_height: Turbine nacelle height in metres
- shape: geographical layout of wind farm
"""
@kwdef struct WindPowerPlant
    power_curve::Array{Float64,2}
    turbine_height::Float64
    shape::Union{Float64,Nothing} = nothing  # wind plant layout (north-south and east-west size in km)
    roughness_length::Float64 = -1.0
end

"""
    struct WindResource

# Fields:
- wind_speed: Wind speed (m/s) time-series
- wind_direction: Wind direction time-series, degrees in clockwise direction from north (i.e. east=90)
- turbulence: Turbulence intensity time-series
- height: Height (m) at which time-series are given
"""
@kwdef struct WindResource
    wind_speed::OperationalProfile
    wind_direction::Union{OperationalProfile,Nothing} = nothing  # Optional, not used for now
    turbulence::Union{OperationalProfile,Nothing} = nothing  # Optional, not used for now
    height::Float64
end

function read_wind_data(filename::String)
    # read source data from file and return WindResource object
    # TODO: Probably move to IO part. Extracting data from CSV, NetCDF, GRIB files or similar?
    return -1
end

"""
    resample_wind_data(wind_resource::WindResource)

Resamples the wind resource to the desired time resolution

# Fields
- wind_resource: Wind resource struct
- resolution: time resolution in resampled time-series
"""
function resample_wind_data(wind_resource::WindResource, resolution::Float64)
    # Change time resolution of time series
    # down-scaling: use average values
    # up-scaling: add power fluctuations
    #  options: interpolate, add_turbulence
    return -1
end

"""
    wind_speed_shear(z::Float64,zw::Float64,z0::Float64)

Computes wind shear scale factor.

# Fields
- `z` : Height (m) at desired wind speed (turbine height)
- `zw`: Height (m) at measured wind speed
- `z0`: Surface roughness length (m)

Comptutes using the formula ``scale = \\frac{\\log{z/z0}}{\\log{zw/z0}}``
"""
function wind_speed_shear(z::Float64, zw::Float64, z0::Float64)
    scale_factor = log(z / z0) / log(zw / z0)
    return scale_factor
end

"""
    power_from_wind(wind_plant: WindPowerPlant, wind_resource: WindResource, 𝒯::TimeStructure)

This function computes available wind power from wind speed

# Fields
- `wind_plant`: struct describing wind power plant
- `wind_resource`: struct describing wind resource
- `scale_windspeed`: scaling factor to apply to wind speed before power curve lookup. If 
  omitted, the scaling factor is computed from the height difference of wind speed 
  measurements and turbine hub height using the wind shear log formula,
"""
function wind_power_from_speed(
    wind_plant::WindPowerPlant,
    wind_resource::WindResource,
    scale_windspeed::Float64 = -1.0,
)
    ws_h1 = wind_resource.wind_speed.vals
    # scale up to desired height
    # TODO: fix scaling
    # If wind speed scaling is not provided, compute using wind shear
    if scale_windspeed <= 0
        z0 = wind_plant.roughness_length
        if z0 <= 0
            throw(
                ArgumentError(
                    "Either scale_windspeed or wind_plant.roughness_length must be specified",
                ),
            )
        end
        scale_factor = wind_speed_shear(wind_plant.turbine_height, wind_resource.height, z0)
    end
    ws_h2 = ws_h1 * scale_factor

    # Convert to power using power curve lookup
    p_curve = wind_plant.power_curve
    itp = linear_interpolation(p_curve[:, 1], p_curve[:, 2], extrapolation_bc = 0)
    power = itp(ws_h2)
    available_wind_power = OperationalProfile(power)
    return available_wind_power

    # TODO: add fluctuations reflecting size of wind plant

end

# TODO: check how best to do this
# - 1:resample speed, 2:compute power OR 1: compute power, 2: resample (and add fluctuations)
#
