"""
    OpenMeteoUnits(temperature_unit, windspeed_unit, precipitation_unit)
    OpenMeteoUnits(;temperature_unit="celsius", windspeed_unit="ms", precipitation_unit="mm")
    
A type that defines the units used for the variabels when calling the [open-meteo.com](https://open-meteo.com/) API.

# Arguments

- `temperature_unit`: the temperature unit, can be "celsius" or "fahrenheit". Default to "celsius".
- `windspeed_unit`: the windspeed unit, can be "ms", "kmh", "mph", or "kn". Default to "ms".
- `precipitation_unit`: the precipitation unit, can be "mm" or "inch". Default to "mm".

# Examples
    
```jldoctest
julia> units = OpenMeteoUnits("celsius", "ms", "mm")
OpenMeteoUnits("celsius", "ms", "mm")
```
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
    OpenMeteo()
    OpenMeteo(
        vars=PlantMeteo.DEFAULT_OPENMETEO_HOURLY,
        forecast_server="https://api.open-meteo.com/v1/forecast",
        historical_server="https://archive-api.open-meteo.com/v1/era5",
        units=OpenMeteoUnits(),
        timezone="UTC",
        models=["auto"]
    )

A type that defines the [open-meteo.com](https://open-meteo.com/) API. 
No need of an API key as it is free. Please keep in mind that the API
is distributed under the AGPL license, that it
is not free for commercial use, and that you should use it responsibly.

# Notes

The API wrapper provided by PlantMeteo is only working for the hourly data as daily data is missing 
some variables. The API wrapper is also not working for the "soil" variables as they are not consistant
between forecast and historical data.

# See also

[`to_daily`](@ref)

# Arguments

- `vars`: the variables needed, see [here](https://open-meteo.com/en/docs).
- `forecast_server`: the server to use for the forecast, see 
[here](https://open-meteo.com/en/docs). Default to `https://api.open-meteo.com/v1/forecast`.
- `historical_server`: the server to use for the historical data, see 
[here](https://open-meteo.com/en/docs). Default to `https://archive-api.open-meteo.com/v1/era5`.
- `units::OpenMeteoUnits`: the units used for the variables, see [`OpenMeteoUnits`](@ref).
- `timezone`: the timezone used for the data, see [the list here](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones). 
Default to "UTC". This parameter is not checked, so be careful when using it.
- `models`: the models to use for the forecast. Default to `"["best_match"]"`. See [`OPENMETEO_MODELS`](@ref) for more details.

# Details

The default variables are: "temperature_2m", "relativehumidity_2m", "precipitation", "surface_pressure", "windspeed_10m",
"shortwave_radiation", "direct_radiation", "diffuse_radiation".

Note that we don't download: "soil_temperature_0cm", "soil_temperature_6cm", "soil_temperature_18cm", "soil_temperature_54cm",
"soil_moisture_0_1cm", "soil_moisture_1_3cm", "soil_moisture_3_9cm", "soil_moisture_9_27cm" and "soil_moisture_27_81cm" 
by default as they are not consistant between forecast and hystorical data.

# Sources 

- [Open-Meteo.com](https://open-meteo.com/), under Attribution 
4.0 International (CC BY 4.0).
- Copernicus Climate Change Service information 2022 (Hersbach et al., 2018).

Hersbach, H., Bell, B., Berrisford, P., Biavati, G., Horányi, A., Muñoz Sabater, J., Nicolas, J., 
Peubey, C., Radu, R., Rozum, I., Schepers, D., Simmons, A., Soci, C., Dee, D., Thépaut, J-N. (2018): 
ERA5 hourly data on single levels from 1959 to present. 
Copernicus Climate Change Service (C3S) Climate Data Store (CDS). (Updated daily), 10.24381/cds.adbb2d47
"""
struct OpenMeteo <: AbstractAPI
    vars::Vector{String}
    forecast_server::String
    historical_server::String
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
    historical_server="https://archive-api.open-meteo.com/v1/era5",
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

    OpenMeteo(vars, forecast_server, historical_server, units, timezone, models)
end

"""
    get_forecast(params::OpenMeteo, lat, lon, period; verbose=true)

A function that returns the weather forecast from OpenMeteo.com

# Arguments

- `lat`: Latitude of the location
- `lon`: Longitude of the location
- `period::Union{StepRange{Date, Day}, Vector{Dates.Date}}`: Period of the forecast
- `verbose`: If `true`, print more information in case of errors or warnings.

# Examples

```julia
using PlantMeteo, Dates
lat = 48.8566
lon = 2.3522
period = [Dates.today(), Dates.today()+Dates.Day(3)]
params = OpenMeteo()
get_forecast(params, lat, lon, period)
```
"""
function get_forecast(params::OpenMeteo, lat, lon, period; verbose=true)

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

    # The ~1km scale forecast API history does not go beyond 196 days 
    # before today:
    start_archive = -Dates.Day(173)
    archive_date = Dates.today() + Dates.Day(start_archive) - Dates.Day(1)
    atms_archive = Atmosphere[]

    if period[1] <= archive_date
        verbose && @info """Open-Meteo.com "forecast" data does not go beyond -173 days ($archive_date).
        Fetching Era5 data for previous dates (0.25° resolution, ~25-30km).        
        """

        max_date = min(archive_date, period[end])

        atms_archive, metadata = fetch_openmeteo(params.historical_server, lat, lon, start_date, max_date, params)

        # If we need "forecast" data, then we restart from the day after archive_date
        start_date = Dates.format(archive_date + Dates.Day(1), "yyyy-mm-dd")
    end

    atms_forecast = Atmosphere[]
    if period[end] > archive_date
        # Get the forecast from open-meteo.com
        atms_forecast, metadata = fetch_openmeteo(params.forecast_server, lat, lon, start_date, end_date, params)
    end

    tst = TimeStepTable(vcat(atms_archive, atms_forecast), metadata)

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
function format_openmeteo!(data; verbose=true)
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