```@meta
CurrentModule = PlantMeteo
```

# Weather Data Sources

This guide explains how PlantMeteo handles weather ingestion and export.

## Design Intent

The package separates concerns:

- ingestion/parsing (`read_weather`, API backends)
- canonical weather representation (`Weather`, `Atmosphere`)
- optional conversion to sink formats (`DataFrame`, custom table sinks)

This keeps model code independent of source-specific quirks.

## Path 1: Local Files with `read_weather`

Use this path when data comes from stations, archives, or partner pipelines.

You can map source-specific column names and units to PlantMeteo variables, and get a standardized `Weather` table with parsed dates/durations and preserved metadata.

```@example apis
using PlantMeteo
using Dates

file = joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv")

meteo = read_weather(
    file,
    :temperature => :T,
    :relativeHumidity => (x -> x ./ 100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)

(length(meteo), metadatakeys(meteo))
```

### Robust Date Parsing for Legacy Files

Some meteorological files encode the date only on the first row and leave it empty for following rows.
`read_weather` can now try several date formats and forward-fill missing dates:

```@example apis
legacy = mktempdir() do tmp
    path = joinpath(tmp, "legacy_meteo.csv")
    write(path, """
date;hour_start;hour_end;temperature;relativeHumidity;wind;clearness
2016/06/12;08:30:00;09:00:00;25;60;1.0;0.6
;09:00:00;09:30:00;25;60;1.0;0.6
""")

    read_weather(
        path,
        :temperature => :T,
        :relativeHumidity => (x -> x ./ 100) => :Rh,
        :wind => :Wind,
        date_formats = (DateFormat("yyyy/mm/dd"), DateFormat("yyyy-mm-dd")),
        forward_fill_date = true,
    )
end

(legacy.date[1], legacy.date[2])
```

You can also validate chronology explicitly with:
- [`row_datetime_interval`](@ref)
- [`check_non_overlapping_timesteps`](@ref)
- [`select_overlapping_timesteps`](@ref)

### Round-trip Export with `write_weather`

Write a clean weather file for reuse, including metadata.

For example we can verify the exported file reproduces the same records:

```@example apis
roundtrip_ok = mktempdir() do tmp
    out = joinpath(tmp, "meteo_out.csv")
    write_weather(out, meteo)
    meteo2 = read_weather(out; duration = Dates.Minute)
    length(meteo) == length(meteo2) && meteo2[1].T == meteo[1].T
end

roundtrip_ok
```

## Path 2: API Retrieval with `get_weather`

Use this path when you don't have local data or need forecast/history for coordinates and dates.

The default API uses Open-Meteo. You can control units, timezone, and model selection before requests, and get a configured API object you can reuse.

```@example apis
params = OpenMeteo(
    units = OpenMeteoUnits(
        temperature_unit = "celsius",
        windspeed_unit = "ms",
        precipitation_unit = "mm"
    ),
    timezone = "UTC",
    models = ["best_match"]
)

(params.timezone, params.models, params.units.temperature_unit)
```

### Define Your Own API Via Our Interface

Any type implementing `get_forecast` can be plugged into `get_weather`. For example, we can define a `DemoAPI` that returns a fixed weather series for any request:

```@example apis
struct DemoAPI <: PlantMeteo.AbstractAPI end

function PlantMeteo.get_forecast(::DemoAPI, lat, lon, period; verbose=true, kwargs...)
    hours = DateTime(period[1]):Hour(1):DateTime(period[end]) + Hour(23)
    rows = Atmosphere[
        Atmosphere(
            date = t,
            duration = Hour(1),
            T = 20.0,
            Wind = 1.0,
            Rh = 0.6,
            P = 101.3,
            Ri_SW_f = 250.0
        )
        for t in hours
    ]
    TimeStepTable(rows, (latitude = lat, longitude = lon, source = "demo"))
end

period = Date(2025, 1, 1):Day(1):Date(2025, 1, 2)
demo = get_weather(48.8566, 2.3522, period; api = DemoAPI())

(length(demo), first(demo).date, last(demo).date)
```

### Switch the Output Sink

You can use the `sink` keyword to get a different output format. For example, we can get a summary of the demo API output instead of the full weather table:

```@example apis
summary = get_weather(
    48.8566,
    2.3522,
    period;
    api = DemoAPI(),
    sink = x -> (n = length(x), first_T = first(x.T), last_date = last(x.date))
)

summary
```

The sink argument can be any sink that implements the `Tables.jl` interface, like `DataFrame`. This allows you to integrate with downstream code that expects specific formats without changing the core API logic.
