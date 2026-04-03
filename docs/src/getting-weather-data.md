```@meta
CurrentModule = PlantMeteo
```

# Getting Weather Data

There are two main entry paths in PlantMeteo:

- start with [`get_weather`](@ref) if you have coordinates and dates but no cleaned file yet
- start with [`read_weather`](@ref) if you already have weather data from stations, archives, or project pipelines

## Path 1: Get Weather From An API

This is the fastest route when downloading weather is the hard part.

```@example getting_data
using PlantMeteo
using Dates

period = Date(2025, 7, 1):Day(1):Date(2025, 7, 2)
api_weather = get_weather(48.8566, 2.3522, period; api = PlantMeteo.DemoAPI())
api_weather[1:4]
```

[`PlantMeteo.DemoAPI()`](@ref) is only for tests, demos, and documentation. It is not an actual
weather service. The default real backend is [`OpenMeteo()`](@ref).

This function can return any type you want via the `sink` keyword, which is a function that transforms the full weather table into a derived object. By default, `sink` is the identity function, but you could use `DataFrame` instead. 

You can also use it to get a summary or a custom struct instead of the full table. For example, you could use `sink` to get a summary of the weather data like this:

```@example getting_data
summary = get_weather(
    48.8566,
    2.3522,
    period;
    api = PlantMeteo.DemoAPI(),
    sink = x -> (
        nsteps = length(x),
        first_date = x[1].date,
        mean_temperature = round(sum(x.T) / length(x), digits = 2),
    )
)
```

```@example getting_data
summary.nsteps
```

```@example getting_data
summary.first_date
```

```@example getting_data
summary.mean_temperature
```

### Using The Built-In Open-Meteo Backend

In normal use, replace `PlantMeteo.DemoAPI()` with [`OpenMeteo()`](@ref):

```julia
using PlantMeteo, Dates

period = Date(2025, 7, 1):Day(1):Date(2025, 7, 3)
weather = get_weather(48.8566, 2.3522, period; api=OpenMeteo())
```

Use this path first when:

- you do not already have trusted local weather files
- you need a quick forecast or a recent historical series
- you want a consistent hourly schema without writing provider-specific glue code

See [Open-Meteo Guide](open-meteo.md) for why Open-Meteo is a good default and when to validate against station data.

## Path 2: Read And Standardize Local Files

Use [`read_weather`](@ref) when you already have weather data but need to map source-specific names and units into PlantMeteo variables.

```@example getting_data
file = joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv")

file_weather = read_weather(
    file,
    :temperature => :T,
    :relativeHumidity => (x -> x ./ 100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)
```

```@example getting_data
length(file_weather)
```

```@example getting_data
file_weather[1].date
```

```@example getting_data
file_weather[1].T
```

PlantMeteo also handles legacy date encodings where only the first row contains the date and later rows must be forward-filled:

```@example getting_data
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
```

```@example getting_data
legacy.date[1]
```

```@example getting_data
legacy.date[2]
```

Use this path first when:

- you already have station or archive files
- you need to preserve curated local data instead of re-downloading
- the main challenge is column naming, units, or date parsing rather than data acquisition

## Choosing Between The Two

- Start with [`get_weather`](@ref) if your problem is getting weather data in the first place.
- Start with [`read_weather`](@ref) if your problem is standardizing weather data you already own.
- After either path, the downstream workflow is the same: inspect the table, aggregate with [`to_daily`](@ref), sample with [`sample_weather`](@ref), or export with [`write_weather`](@ref).
