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

const OPENMETEO_RETRYABLE_STATUS_CODES = (408, 429, 500, 502, 503, 504)
const OPENMETEO_DEFAULT_RETRIES = 2
const OPENMETEO_DEFAULT_RETRY_DELAY_SECONDS = 0.5

struct OpenMeteoRequestError <: Exception
    segment::String
    start_date::String
    end_date::String
    url::String
    attempts::Int
    reason::String
end

function Base.showerror(io::IO, err::OpenMeteoRequestError)
    print(
        io,
        "Open-Meteo ",
        err.segment,
        " request failed for ",
        err.start_date,
        " to ",
        err.end_date,
        " after ",
        err.attempts,
        " attempt",
        err.attempts == 1 ? "" : "s",
        ": ",
        err.reason,
        ". URL: ",
        err.url
    )
end

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

        atms_archive, metadata = fetch_openmeteo(
            params.historical_server,
            lat,
            lon,
            start_date,
            max_date,
            params;
            segment="archive",
            kwargs...
        )

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
            params;
            segment="historical forecast",
            kwargs...
        )

        start_date = Dates.format(historical_forecast_max + Dates.Day(1), "yyyy-mm-dd")
    end

    atms_forecast = Atmosphere[]
    if period[end] > historical_forecast_end
        # Get the forecast from open-meteo.com
        atms_forecast, metadata = fetch_openmeteo(
            params.forecast_server,
            lat,
            lon,
            start_date,
            end_date,
            params;
            segment="forecast",
            kwargs...
        )
    end

    tst = TimeStepTable(vcat(atms_archive, atms_historical_forecast, atms_forecast), metadata)

    return tst
end

"""
    fetch_openmeteo(url, lat, lon, start_date, end_date, params::OpenMeteo)

Fetches the weather forecast from OpenMeteo.com and returns a tuple of: 

- a vector of [`Atmosphere`](@ref)
- a `NamedTuple` of metadata (e.g. `elevation`, `timezone`, canonical `units`,
  `source_units`, and the deterministic `import_normalization` history)

"""
function fetch_openmeteo(
    url,
    lat,
    lon,
    start_date,
    end_date,
    params::T;
    segment="forecast",
    request_get=HTTP.get,
    retries=OPENMETEO_DEFAULT_RETRIES,
    retry_delay=OPENMETEO_DEFAULT_RETRY_DELAY_SECONDS,
    sleep_fn=sleep,
) where {T<:OpenMeteo}
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

    response, attempts = openmeteo_get_with_retry(
        url_archive;
        segment=segment,
        start_date=start_date,
        end_date=end_date,
        request_get=request_get,
        retries=retries,
        retry_delay=retry_delay,
        sleep_fn=sleep_fn
    )

    data = parse_openmeteo_response(
        response,
        url_archive,
        segment,
        start_date,
        end_date,
        attempts
    )

    formatted = format_openmeteo(data, params.units)

    return (
        formatted.atmospheres,
        (
            latitude=data["latitude"],
            longitude=data["longitude"],
            elevation=data["elevation"],
            timezone=data["timezone"],
            units=formatted.units,
            source_units=Dict{String,Any}(data["hourly_units"]),
            timezone_abbreviation=data["timezone_abbreviation"],
            import_normalization=formatted.import_normalization,
        )
    )
end

function openmeteo_get_with_retry(
    url;
    segment,
    start_date,
    end_date,
    request_get,
    retries,
    retry_delay,
    sleep_fn,
)
    attempts = retries + 1
    last_reason = "request did not complete"

    for attempt in 1:attempts
        try
            response = request_get(url; status_exception=false)
            if response.status in OPENMETEO_RETRYABLE_STATUS_CODES
                last_reason = "HTTP $(response.status)"
                attempt < attempts && sleep_fn(retry_delay * attempt)
                continue
            elseif response.status < 200 || response.status >= 300
                throw(OpenMeteoRequestError(
                    segment,
                    start_date,
                    end_date,
                    url,
                    attempt,
                    "HTTP $(response.status)"
                ))
            end

            return response, attempt
        catch err
            transient = is_transient_openmeteo_error(err)
            last_reason = openmeteo_error_reason(err)

            if transient && attempt < attempts
                sleep_fn(retry_delay * attempt)
                continue
            end

            if transient
                throw(OpenMeteoRequestError(segment, start_date, end_date, url, attempt, last_reason))
            end

            rethrow()
        end
    end

    throw(OpenMeteoRequestError(segment, start_date, end_date, url, attempts, last_reason))
end

function parse_openmeteo_response(response, url, segment, start_date, end_date, attempts)
    data = try
        JSON.parse(String(response.body))
    catch err
        throw(OpenMeteoRequestError(
            segment,
            start_date,
            end_date,
            url,
            attempts,
            "invalid JSON response ($(typeof(err)))"
        ))
    end

    validate_openmeteo_response(data, url, segment, start_date, end_date, attempts)

    return data
end

function validate_openmeteo_response(data, url, segment, start_date, end_date, attempts)
    required_top_level = ("latitude", "longitude", "elevation", "timezone", "hourly_units", "timezone_abbreviation", "hourly")
    for key in required_top_level
        haskey(data, key) || throw(OpenMeteoRequestError(
            segment,
            start_date,
            end_date,
            url,
            attempts,
            "response is missing key \"$key\""
        ))
    end

    hourly = data["hourly"]
    hourly isa AbstractDict || throw(OpenMeteoRequestError(
        segment,
        start_date,
        end_date,
        url,
        attempts,
        "response key \"hourly\" is not an object"
    ))

    required_hourly = (
        "time",
        "surface_pressure",
        "windspeed_10m",
        "temperature_2m",
        "relativehumidity_2m",
        "precipitation",
        "shortwave_radiation",
        "direct_radiation",
        "diffuse_radiation",
    )
    for key in required_hourly
        haskey(hourly, key) || throw(OpenMeteoRequestError(
            segment,
            start_date,
            end_date,
            url,
            attempts,
            "response hourly payload is missing key \"$key\""
        ))
    end
end

is_transient_openmeteo_error(::HTTP.TimeoutError) = true
is_transient_openmeteo_error(::HTTP.ConnectError) = true
is_transient_openmeteo_error(err::HTTP.StatusError) = err.status in OPENMETEO_RETRYABLE_STATUS_CODES
is_transient_openmeteo_error(err) = err isa EOFError || err isa Base.IOError

@static if isdefined(HTTP, :TLSHandshakeError)
    is_transient_openmeteo_error(::HTTP.TLSHandshakeError) = true
end

openmeteo_error_reason(err::HTTP.TimeoutError) = "request timed out"
function openmeteo_error_reason(err::HTTP.ConnectError)
    cause = hasproperty(err, :error) ? err.error : err.cause
    return "connection failed: $cause"
end
openmeteo_error_reason(err::HTTP.StatusError) = "HTTP $(err.status)"
openmeteo_error_reason(err) = sprint(showerror, err)

@static if isdefined(HTTP, :RequestError)
    is_transient_openmeteo_error(err::HTTP.RequestError) = is_transient_openmeteo_error(err.error)
    openmeteo_error_reason(err::HTTP.RequestError) = openmeteo_error_reason(err.error)
end

"""
    format_openmeteo(data, units=OpenMeteoUnits(); constant=Constants())

Format an Open-Meteo JSON payload into canonical [`Atmosphere`](@ref) rows.

The request's explicit `OpenMeteoUnits` configuration drives all conversions;
values are never used to guess units. The source payload is left unchanged.
The return value contains `atmospheres`, canonical `units`, and a YAML-safe
`import_normalization` history.
"""
function format_openmeteo(data, units::OpenMeteoUnits=OpenMeteoUnits(); constant=Constants())
    atms = Atmosphere[]
    unit_specs = _openmeteo_unit_specs(units)
    _validate_openmeteo_normalization_units(data["hourly_units"], unit_specs)
    datetime = [Dates.DateTime(i, Dates.dateformat"yyyy-mm-ddTHH:MM") for i in data["hourly"]["time"]]

    # Duration in sensible units (e.g. 1 hour, or 1 day)
    duration = timesteps_durations(datetime)

    raw_units = (
        T=[
            check_and_parse(value, "Temperature", datetime[i])
            for (i, value) in enumerate(data["hourly"]["temperature_2m"])
        ],
        Wind=[
            check_and_parse(value, "Wind speed", datetime[i])
            for (i, value) in enumerate(data["hourly"]["windspeed_10m"])
        ],
        Precipitations=[
            check_and_parse(value, "Precipitation", datetime[i])
            for (i, value) in enumerate(data["hourly"]["precipitation"])
        ],
        Rh=[
            check_and_parse(value, "Relative humidity", datetime[i])
            for (i, value) in enumerate(data["hourly"]["relativehumidity_2m"])
        ],
        P=[
            check_and_parse(value, "Surface pressure", datetime[i])
            for (i, value) in enumerate(data["hourly"]["surface_pressure"])
        ],
    )
    normalized = _normalize_openmeteo_import(raw_units, unit_specs)

    for i in 1:length(data["hourly"]["time"])
        P = normalized.data.P[i]
        Wind = normalized.data.Wind[i]
        T = normalized.data.T[i]
        Rh = normalized.data.Rh[i]
        Precip = normalized.data.Precipitations[i]
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

    return (
        atmospheres=atms,
        units=_canonical_openmeteo_units(data["hourly_units"]),
        import_normalization=_weather_import_provenance_history(normalized.provenance),
    )
end

function _openmeteo_unit_specs(units::OpenMeteoUnits)
    temperature = if units.temperature_unit == "celsius"
        (input_unit=:celsius, output_unit=:celsius, payload_unit="°C", scale=1.0, offset=0.0)
    else
        (input_unit=:fahrenheit, output_unit=:celsius, payload_unit="°F", scale=5.0 / 9.0, offset=-32.0 * 5.0 / 9.0)
    end

    wind = if units.windspeed_unit == "ms"
        (input_unit=:ms, output_unit=:ms, payload_unit="m/s", scale=1.0, offset=0.0)
    elseif units.windspeed_unit == "kmh"
        (input_unit=:kmh, output_unit=:ms, payload_unit="km/h", scale=1.0 / 3.6, offset=0.0)
    elseif units.windspeed_unit == "mph"
        (input_unit=:mph, output_unit=:ms, payload_unit="mp/h", scale=0.44704, offset=0.0)
    else
        (input_unit=:kn, output_unit=:ms, payload_unit="kn", scale=1852.0 / 3600.0, offset=0.0)
    end

    precipitation = if units.precipitation_unit == "mm"
        (input_unit=:mm, output_unit=:mm, payload_unit="mm", scale=1.0, offset=0.0)
    else
        (input_unit=:inch, output_unit=:mm, payload_unit="inch", scale=25.4, offset=0.0)
    end

    return (
        T=temperature,
        Wind=wind,
        Precipitations=precipitation,
        Rh=(input_unit=:percent, output_unit=:fraction, payload_unit="%", scale=0.01, offset=0.0),
        P=(input_unit=:hPa, output_unit=:kPa, payload_unit="hPa", scale=0.1, offset=0.0),
    )
end

function _normalize_openmeteo_import(data, unit_specs)
    normalized = data
    conversions = NamedTuple[]
    for variable in (:T, :Wind, :Precipitations)
        spec = getproperty(unit_specs, variable)
        normalized, conversion = _normalize_openmeteo_import_column(
            normalized,
            variable,
            spec,
        )
        conversion === nothing || push!(conversions, conversion)
    end

    core = normalize_weather_import(
        normalized;
        input_units=(Rh=unit_specs.Rh.input_unit, P=unit_specs.P.input_unit),
    )
    append!(conversions, core.provenance.conversions)

    provenance = (
        input_units=(
            T=unit_specs.T.input_unit,
            Wind=unit_specs.Wind.input_unit,
            Precipitations=unit_specs.Precipitations.input_unit,
            Rh=core.provenance.input_units.Rh,
            P=core.provenance.input_units.P,
        ),
        output_units=(
            T=unit_specs.T.output_unit,
            Wind=unit_specs.Wind.output_unit,
            Precipitations=unit_specs.Precipitations.output_unit,
            Rh=core.provenance.output_units.Rh,
            P=core.provenance.output_units.P,
        ),
        conversions=Tuple(conversions),
    )
    return (data=core.data, provenance=provenance)
end

function _normalize_openmeteo_import_column(data, variable, spec)
    iszero(spec.offset) && return _normalize_weather_import_column(
        data,
        variable,
        spec.input_unit,
        spec.output_unit,
        spec.scale,
    )

    hasproperty(data, variable) || return data, nothing
    values_ = map(Tables.getcolumn(data, variable)) do value
        ismissing(value) ? missing : value * spec.scale + spec.offset
    end
    normalized = set_column(data, variable, values_)
    conversion = (
        variable=variable,
        input_unit=spec.input_unit,
        output_unit=spec.output_unit,
        scale=spec.scale,
        offset=spec.offset,
    )
    return normalized, conversion
end

function _validate_openmeteo_normalization_units(units, unit_specs)
    expected = (
        time="iso8601",
        temperature_2m=unit_specs.T.payload_unit,
        windspeed_10m=unit_specs.Wind.payload_unit,
        precipitation=unit_specs.Precipitations.payload_unit,
        relativehumidity_2m=unit_specs.Rh.payload_unit,
        surface_pressure=unit_specs.P.payload_unit,
        shortwave_radiation="W/m²",
        direct_radiation="W/m²",
        diffuse_radiation="W/m²",
    )
    for (variable, expected_unit) in pairs(expected)
        key = string(variable)
        actual = get(units, key, nothing)
        actual == expected_unit || throw(ArgumentError(
            "Open-Meteo unit for `$key` must be `$expected_unit` before normalization, got $(repr(actual))",
        ))
    end
    return nothing
end

function _canonical_openmeteo_units(source_units)
    units = Dict{String,Any}(source_units)
    units["temperature_2m"] = "°C"
    units["windspeed_10m"] = "m/s"
    units["precipitation"] = "mm"
    units["relativehumidity_2m"] = "0-1"
    units["surface_pressure"] = "kPa"
    return units
end

function check_and_parse(x, type, date)
    if x === nothing
        error(
            "$type data is `nothing` on $date."
        )
    end

    return Float64(x)
end
