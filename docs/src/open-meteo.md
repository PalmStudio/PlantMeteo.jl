```@meta
CurrentModule = PlantMeteo
```

# Open-Meteo Guide

[`OpenMeteo`](@ref) is the built-in API backend in PlantMeteo. It exists to solve a practical problem: downloading weather data is often harder than using it. PlantMeteo wraps Open-Meteo behind the same [`get_weather`](@ref) interface used by any custom backend, so model workflows can start from coordinates and dates without forcing each project to write its own downloader.

## Why Open-Meteo Is A Good Default

Open-Meteo is a practical default because it combines several things that are useful in modeling workflows:

- coordinate-based access instead of station-specific file handling
- hourly variables exposed through a consistent API
- forecast data and older archive data reachable through one backend
- little setup friction for exploratory and research use

For many users, that means you can get to a usable [`Weather`](@ref) table much faster than with manual data collection.

## Where The Data Comes From

PlantMeteo's [`OpenMeteo`](@ref) wrapper uses two kinds of Open-Meteo endpoints:

- a forecast endpoint for recent and future weather
- a historical archive endpoint for older periods

In PlantMeteo's wrapper, the historical endpoint is the ERA5-based archive exposed by Open-Meteo, while the forecast endpoint exposes weather models selected through Open-Meteo's API. In practice, this is why the same PlantMeteo call can cover both retrospective runs and short-term forecasts.

This does not mean every period comes from the same underlying product or resolution. Forecast and archive data can differ in spatial resolution, upstream source, and update behavior. PlantMeteo keeps the interface consistent, but it does not erase those physical differences.

## Why This Is Useful In Practice

The main benefits for PlantMeteo users are:

- you can request hourly weather from latitude, longitude, and date range
- the response is converted directly into PlantMeteo variables
- you can use the same downstream code whether the data came from Open-Meteo or a local CSV
- you can keep one API for both recent forecasts and older historical periods

The result is a shorter path from "I need weather for this site" to "I can inspect, aggregate, and feed it to the model".

## Limits And Tradeoffs

Open-Meteo is useful, but it should be presented honestly:

- it is a network dependency, so live calls can fail or slow down
- forecast availability is limited to the horizon exposed by Open-Meteo
- historical archive data and forecast data do not necessarily share the same effective resolution
- upstream model availability can evolve over time
- licensing and commercial-use conditions should be checked for your actual use case

PlantMeteo uses Open-Meteo because it is practical, not because it is universally better than local observations.

## When To Trust It And When To Validate It

Open-Meteo is often a good fit when:

- you need a quick, consistent weather source for research and model development
- you are working in locations where station data is difficult to collect
- you need a convenient baseline dataset before more detailed validation

Validate against local station data when:

- the site has strong local microclimate effects
- the model is sensitive to biases in radiation, humidity, precipitation, or wind
- your workflow is high-stakes enough that convenience is not enough

## Configuring The Backend

You can configure units, timezone, and model selection without making a network call:

```@example openmeteo
using PlantMeteo

params = OpenMeteo(
    units = OpenMeteoUnits(
        temperature_unit = "celsius",
        windspeed_unit = "ms",
        precipitation_unit = "mm"
    ),
    timezone = "UTC",
    models = ["best_match"]
)
```

```@example openmeteo
params.timezone
```

```@example openmeteo
params.models
```

```@example openmeteo
params.units.temperature_unit
```

And this is what a real call looks like:

```julia
using PlantMeteo, Dates

period = Date(2025, 7, 1):Day(1):Date(2025, 7, 3)
weather = get_weather(48.8566, 2.3522, period; api=OpenMeteo())
```

The docs keep this as a non-executed snippet so the site build remains deterministic and offline.
