


"""
    OpenMeteo()
    OpenMeteo(vars)

A type that defines the [open-meteo.com](https://open-meteo.com/) API. 
No need of an API key as it is free. Please keep in mind that the API
is not free for commercial use, and that you should use it responsibly.

# Arguments

- `vars`: the variables needed, see [here](https://open-meteo.com/en/docs).

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
    vars
end

function OpenMeteo()
    OpenMeteo(
        [
        "temperature_2m", "relativehumidity_2m", "precipitation", "surface_pressure", "windspeed_10m",
        # We remove these by default as they are not consistant between forecast and hystorical data:
        # "soil_temperature_0cm", "soil_temperature_6cm", "soil_temperature_18cm", "soil_temperature_54cm",
        # "soil_moisture_0_1cm", "soil_moisture_1_3cm", "soil_moisture_3_9cm", "soil_moisture_9_27cm", "soil_moisture_27_81cm",
        "shortwave_radiation", "direct_radiation", "diffuse_radiation"
    ]
    )
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
period = Dates.today():Dates.Day(1):Dates.today()+Dates.Day(3)
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
    start_archive = -Dates.Day(196)
    archive_date = Dates.today() + Dates.Day(start_archive) - Dates.Day(1)
    atms_archive = Atmosphere[]

    vars = join(params.vars, ",")

    if period[1] <= archive_date
        @info """Open-Meteo.com "forecast" data does not go beyond -196 days ($archive_date).
        Fetching Era5 data for previous dates (0.25° resolution, ~25-30km).        
        """
        max_date = min(archive_date, period[end])
        url_archive = "https://archive-api.open-meteo.com/v1/era5?latitude=$lat&longitude=$lon&start_date=$start_date&end_date=$max_date&hourly=$vars&timezone=auto&windspeed_unit=ms"
        data = HTTP.get(url_archive)
        data = JSON.parse(String(data.body))
        atms_archive = format_openmeteo!(data)

        # If we need "forecast" data, then we restart from the day after archive_date
        start_date = Dates.format(archive_date + Dates.Day(1), "yyyy-mm-dd")
    end

    atms_forecast = Atmosphere[]
    if period[end] > archive_date
        # Get the forecast from open-meteo.com
        url_forecast = "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&hourly=$vars&models=best_match&windspeed_unit=ms&timezone=auto&start_date=$start_date&end_date=$end_date"
        data = HTTP.get(url_forecast)
        data = JSON.parse(String(data.body))
        atms_forecast = format_openmeteo!(data; verbose=verbose)
    end

    tst = TimeStepTable(
        vcat(atms_archive, atms_forecast),
        (
            latitude=data["latitude"],
            longitude=data["longitude"],
            elevation=data["elevation"],
            timezone=data["timezone"],
            units=data["hourly_units"],
            timezone_abbreviation=data["timezone_abbreviation"],
        )
    )

    return tst
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

        push!(atms,
            Atmosphere(
                date=datetime[i],
                duration=duration[i],
                T=Float64(data["hourly"]["temperature_2m"][i]),
                Wind=Float64(data["hourly"]["windspeed_10m"][i]),
                Rh=Float64(data["hourly"]["relativehumidity_2m"][i]) / 100.0,
                P=P,
                Precipitations=Float64(data["hourly"]["precipitation"][i]),
                Ri_SW_f=Float64(data["hourly"]["shortwave_radiation"][i]),
                Ri_SW_f_direct=Float64(data["hourly"]["direct_radiation"][i]),
                Ri_SW_f_diffuse=Float64(data["hourly"]["direct_radiation"][i]),
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

    data["hourly_units"]["relativehumidity_2m"] = "-"
    data["hourly_units"]["surface_pressure"] = "kPa"

    return atms
end

