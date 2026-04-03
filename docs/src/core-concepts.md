```@meta
CurrentModule = PlantMeteo
```

# Core Concepts

The package is easiest to understand if you keep three objects in mind:

- [`Atmosphere`](@ref): one timestep of atmospheric conditions
- [`Weather`](@ref): a convenient constructor for weather tables made of `Atmosphere` rows
- [`TimeStepTable`](@ref): the underlying table abstraction used across the package

## `Atmosphere`: One Timestep

```@example concepts
using PlantMeteo
using Dates

row = Atmosphere(
    date = DateTime(2025, 7, 1, 12),
    duration = Hour(1),
    T = 24.0,
    Wind = 1.8,
    Rh = 0.58,
    P = 101.3,
    Ri_SW_f = 620.0
)

row
```

An `Atmosphere` row stores one weather timestep. Some variables are mandatory (`T`, `Wind`, `Rh`), while others are optional or can be computed from those core inputs.

## `Weather`: A Convenient Weather Constructor

```@example concepts
weather = Weather(
    [
        row,
        Atmosphere(
            date = DateTime(2025, 7, 1, 13),
            duration = Hour(1),
            T = 25.0,
            Wind = 2.0,
            Rh = 0.55,
            P = 101.3,
            Ri_SW_f = 580.0
        ),
    ],
    (site = "demo", source = "synthetic")
)

weather
```

`Weather` is usually the easiest way to say "this is a weather table made of atmospheric rows".

## `TimeStepTable`: The Shared Table Abstraction

`Weather` is built on top of [`TimeStepTable`](@ref), which exposes row access, column access, metadata, and the `Tables.jl` interface.

```@example concepts
weather[1]
```

```@example concepts
weather[:T]
```

```@example concepts
weather[2, :T]
```

```@example concepts
metadatakeys(weather)
```

This is what makes the rest of the package coherent: whether the data came from an API, a CSV file, or a synthetic example, you work with the same table abstraction afterward.

## Metadata

Metadata is attached to the table, not to each row:

```@example concepts
metadata(weather)
```

This is useful for keeping site information, provenance, or source notes attached to the weather series.

## Variables And Units

PlantMeteo expects canonical variable names and units in `Atmosphere` rows. For example:

- `T`: air temperature in degrees Celsius
- `Rh`: relative humidity in 0-1 units
- `Wind`: wind speed in m s-1
- `P`: air pressure in kPa
- `Ri_SW_f`: incoming short-wave radiation flux in W m-2

This is why [`read_weather`](@ref) matters: local files rarely arrive with these exact names and units.

## What Comes Next

- Use [Getting Weather Data](getting-weather-data.md) to build a `Weather` table from an API or a local file.
- Use [Daily Aggregation](daily-aggregation.md) when you want one row per day.
- Use [Weather Sampling](weather-sampling.md) when you want model-aligned windows instead of fixed daily rows.
