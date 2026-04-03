"""
    OpenMeteoUnits(...)

Unit configuration passed to [`OpenMeteo`](@ref).

Use this when you want to control how temperature, wind speed, and precipitation are requested from
Open-Meteo before PlantMeteo converts the result into a weather table.
"""
struct OpenMeteoUnits
    temperature_unit
    windspeed_unit
    precipitation_unit

    function OpenMeteoUnits(temperature_unit, windspeed_unit, precipitation_unit)
        @assert temperature_unit in ["celsius", "fahrenheit"] """
        Temperature unit ("$temperature_unit") must be either "celsius" or "fahrenheit"."""
        @assert windspeed_unit in ["ms", "kmh", "mph", "kn"] """
        Wind speed unit ("$windspeed_unit") must be either "ms", "kmh", "mph", or "kn"."""
        @assert precipitation_unit in ["mm", "inch"] """
        Precipitation unit ("$precipitation_unit") must be either "mm" or "inch"."""
        new(temperature_unit, windspeed_unit, precipitation_unit)
    end
end

function OpenMeteoUnits(; temperature_unit="celsius", windspeed_unit="ms", precipitation_unit="mm")
    OpenMeteoUnits(temperature_unit, windspeed_unit, precipitation_unit)
end


"""
    OpenMeteo(; kwargs...)

Built-in PlantMeteo backend for the [Open-Meteo](https://open-meteo.com/) API.

Use `OpenMeteo()` with [`get_weather`](@ref) when you want the fastest path from coordinates and
dates to a usable weather table. PlantMeteo uses Open-Meteo's forecast endpoint for recent/future
periods, a historical forecast endpoint for recent past periods, and its ERA5-based archive endpoint
for older periods. That makes the same interface practical for both short-term forecasts and
retrospective runs.

# Why it is useful

- no API-specific glue code in your modeling project
- hourly weather variables behind one backend
- recent forecast data and older historical data through the same interface

# Important caveats

- calls require network access
- forecast, historical forecast, and archive data may differ in source and resolution
- usage terms should be checked for your real use case, especially commercial use

# Key arguments

- `vars`: Open-Meteo hourly variables to request.
- `start_archive`: cutoff deciding when PlantMeteo switches to the archive endpoint.
- `units`: unit configuration, see [`OpenMeteoUnits`](@ref).
- `timezone`: timezone requested from Open-Meteo.
- `models`: forecast models exposed by Open-Meteo.

# Example

```julia
using PlantMeteo, Dates

api = OpenMeteo(timezone="UTC", models=["best_match"])
period = Date(2025, 7, 1):Day(1):Date(2025, 7, 3)
weather = get_weather(48.8566, 2.3522, period; api=api)
```
"""
struct OpenMeteo <: AbstractAPI
    vars::Vector{String}
    forecast_server::String
    historical_forecast_server::String
    historical_server::String
    start_archive::Dates.Day
    units::OpenMeteoUnits
    timezone::String
    models::Vector{String}
end

"""
    DEFAULT_OPENMETEO_HOURLY

Default variables downloaded for an Open-Meteo forecast. See [here](https://open-meteo.com/en/docs) for more.
"""
const DEFAULT_OPENMETEO_HOURLY = [
    "temperature_2m", "relativehumidity_2m", "precipitation", "surface_pressure", "windspeed_10m",
    "shortwave_radiation", "direct_radiation", "diffuse_radiation"
]

"""
    OPENMETEO_MODELS

Possible models for the forecast. See [here](https://open-meteo.com/en/docs) for more details.
"""
const OPENMETEO_MODELS = [
    "best_match", "ecmwf_ifs04", "metno_nordic", "gfs_seamless", "gfs_global", "gfs_hrrr", "jma_seamless", "jma_msm", "jms_gsm",
    "icon_seamless", "icon_global", "icon_eu", "icon_d2", "gem_seamless", "gem_global", "gem_regional",
    "gem_hrdps_continental", "meteofrance_seamless", "meteofrance_arpege_world", "meteofrance_arpege_europe",
    "meteofrance_arome_france", "meteofrance_arome_france_hd"
]

function OpenMeteo(;
    vars=DEFAULT_OPENMETEO_HOURLY,
    forecast_server="https://api.open-meteo.com/v1/forecast",
    historical_forecast_server="https://historical-forecast-api.open-meteo.com/v1/forecast",
    historical_server="https://archive-api.open-meteo.com/v1/era5",
    start_archive=Dates.Date(2022, 1, 1) - Dates.today(),
    units=OpenMeteoUnits(),
    timezone="UTC",
    models=["best_match"]
)
    if !isa(vars, Vector)
        vars = [vars]
    end

    if !isa(models, Vector)
        models = [models]
    end

    for i in models
        @assert i in OPENMETEO_MODELS "The model $i is not available. See OPENMETEO_MODELS for more details."
    end

    OpenMeteo(vars, forecast_server, historical_forecast_server, historical_server, start_archive, units, timezone, models)
end

"""
    get_forecast(params::OpenMeteo, lat, lon, period; verbose=true, kwargs...)

Live Open-Meteo request used internally by [`get_weather`](@ref).

This method returns a `TimeStepTable{Atmosphere}` built from Open-Meteo responses. Most users
should call [`get_weather`](@ref) rather than invoking `get_forecast` directly.
"""
function get_forecast(params::OpenMeteo, lat, lon, period; verbose=true, kwargs...)

    period[1] > period[end] && error("start date must be before end date")

    # Format start and end dates
    start_date = Dates.format(period[1], "yyyy-mm-dd")
    end_date = Dates.format(period[end], "yyyy-mm-dd")
    max_date_forecast = Dates.today() + Dates.Day(15)

    if period[end] > max_date_forecast
        error(
            "Open-Meteo.com forecast 15 days in the future only,",
            " *i.e.* until $max_date_forecast. You asked for $end_date."
        )
    end

    archive_date = Dates.today() + params.start_archive - Dates.Day(1)
    atms_archive = Atmosphere[]
    atms_historical_forecast = Atmosphere[]
    metadata = nothing

    historical_forecast_end = Dates.today() - Dates.Day(1)

    if period[1] <= archive_date
        verbose && @info """Fetching Open-Meteo archive data through $archive_date.
        Older dates use ERA5 data (~25-30km resolution).        
        """

        max_date = min(archive_date, period[end])

        atms_archive, metadata = fetch_openmeteo(params.historical_server, lat, lon, start_date, max_date, params)

        # If we need newer data, then restart from the day after archive_date
        start_date = Dates.format(archive_date + Dates.Day(1), "yyyy-mm-dd")
    end

    if period[end] > archive_date && period[1] <= historical_forecast_end
        verbose && @info """Fetching Open-Meteo historical forecast data through $historical_forecast_end.
        Recent past dates use archived high-resolution forecast data.        
        """

        historical_forecast_start = max(period[1], archive_date + Dates.Day(1))
        historical_forecast_max = min(historical_forecast_end, period[end])
        historical_forecast_start_date = Dates.format(historical_forecast_start, "yyyy-mm-dd")
        historical_forecast_end_date = Dates.format(historical_forecast_max, "yyyy-mm-dd")

        atms_historical_forecast, metadata = fetch_openmeteo(
            params.historical_forecast_server,
            lat,
            lon,
            historical_forecast_start_date,
            historical_forecast_end_date,
            params
        )

        start_date = Dates.format(historical_forecast_max + Dates.Day(1), "yyyy-mm-dd")
    end

    atms_forecast = Atmosphere[]
    if period[end] > historical_forecast_end
        # Get the forecast from open-meteo.com
        atms_forecast, metadata = fetch_openmeteo(params.forecast_server, lat, lon, start_date, end_date, params)
    end

    tst = TimeStepTable(vcat(atms_archive, atms_historical_forecast, atms_forecast), metadata)

    return tst
end

"""
    fetch_openmeteo(url, lat, lon, start_date, end_date, params::OpenMeteo)

Fetches the weather forecast from OpenMeteo.com and returns a tuple of: 

- a vector of [`Atmosphere`](@ref)
- a `NamedTuple` of metadata (e.g. `elevation`, `timezone`, `units`...)

"""
function fetch_openmeteo(url, lat, lon, start_date, end_date, params::T) where {T<:OpenMeteo}
    # Format API parameters:
    API_params = (
        latitude=lat,
        longitude=lon,
        hourly=join(params.vars, ","),
        models=join(params.models, ","),
        windspeed_unit=params.units.windspeed_unit,
        temperature_unit=params.units.temperature_unit,
        precipitation_unit=params.units.precipitation_unit,
        timezone=params.timezone,
        start_date=start_date,
        end_date=end_date,
        API=T,
        url=url,
    )
    API_params = join([string(k, "=", v) for (k, v) in pairs(API_params)], "&")

    url_archive = string(url, "?", API_params)

    data = HTTP.get(url_archive)
    data = JSON.parse(String(data.body))

    return (
        format_openmeteo!(data),
        (
            latitude=data["latitude"],
            longitude=data["longitude"],
            elevation=data["elevation"],
            timezone=data["timezone"],
            units=data["hourly_units"],
            timezone_abbreviation=data["timezone_abbreviation"],
        )
    )
end

"""
    format_openmeteo(data)

Format the JSON file returned by the Open-Meteo API into a vector 
of [`Atmosphere`](@ref). The function also updates some units in `data`.
"""
function format_openmeteo!(data; constant=Constants(), verbose=true)
    atms = Atmosphere[]
    datetime = [Dates.DateTime(i, Dates.dateformat"yyyy-mm-ddTHH:MM") for i in data["hourly"]["time"]]

    # Duration in sensible units (e.g. 1 hour, or 1 day)
    duration = timesteps_durations(datetime)

    for i in 1:length(data["hourly"]["time"])
        P = data["hourly"]["surface_pressure"][i]

        if P === nothing
            verbose && @warn string(
                "Surface pressure data is `nothing` on $(datetime[i]).",
                "Using default value $(DEFAULTS.P)."
            ) maxlog = 10
            P = DEFAULTS.P
        else
            P = Float64(P) / 10.0
        end

        # To avoid warnings in atmosphere:
        if data["hourly"]["windspeed_10m"][i] === nothing
            Wind = 1.0e-6
        else
            Wind = Float64(data["hourly"]["windspeed_10m"][i])
            if Wind <= 0.0
                Wind = 1.0e-6
            end
        end

        T = check_and_parse(data["hourly"]["temperature_2m"][i], "Temperature", datetime[i])
        Rh = check_and_parse(data["hourly"]["relativehumidity_2m"][i], "Relative humidity", datetime[i]) / 100.0
        Precip = check_and_parse(data["hourly"]["precipitation"][i], "Precipitation", datetime[i])
        Ri_SW_f = check_and_parse(data["hourly"]["shortwave_radiation"][i], "Shortwave radiation", datetime[i])
        Ri_SW_f_direct = check_and_parse(data["hourly"]["direct_radiation"][i], "Direct radiation", datetime[i])
        Ri_SW_f_diffuse = check_and_parse(data["hourly"]["diffuse_radiation"][i], "Diffuse radiation", datetime[i])

        push!(atms,
            Atmosphere(
                date=datetime[i],
                duration=duration[i],
                T=T,
                Wind=Wind,
                Rh=Rh,
                P=P,
                Precipitations=Precip,
                Ri_SW_f=Ri_SW_f,
                Ri_SW_f_direct=Ri_SW_f_direct,
                Ri_SW_f_diffuse=Ri_SW_f_diffuse,
                Ri_PAR_f=Ri_SW_f * constant.PAR_fraction,
                Ri_NIR_f=Ri_SW_f * (1.0 - constant.PAR_fraction),
                # This is not so standard in meteo data, and we probably recompute it but it is useful to have it:
                # soil_temperature_0cm=Float64(data["hourly"]["soil_temperature_0cm"][i]),
                # soil_temperature_6cm=Float64(data["hourly"]["soil_temperature_6cm"][i]),
                # soil_temperature_18cm=Float64(data["hourly"]["soil_temperature_18cm"][i]),
                # soil_temperature_54cm=Float64(data["hourly"]["soil_temperature_54cm"][i]),
                # soil_moisture_0_1cm=Float64(data["hourly"]["soil_moisture_0_1cm"][i]),
                # soil_moisture_1_3cm=Float64(data["hourly"]["soil_moisture_1_3cm"][i]),
                # soil_moisture_3_9cm=Float64(data["hourly"]["soil_moisture_3_9cm"][i]),
                # soil_moisture_9_27cm=Float64(data["hourly"]["soil_moisture_9_27cm"][i]),
                # soil_moisture_27_81cm=Float64(data["hourly"]["soil_moisture_27_81cm"][i]),
            )
        )
    end

    data["hourly_units"]["relativehumidity_2m"] = "0-1"
    data["hourly_units"]["surface_pressure"] = "kPa"

    return atms
end

function check_and_parse(x, type, date)
    if x === nothing
        error(
            "$type data is `nothing` on $date."
        )
    end

    return Float64(x)
end
