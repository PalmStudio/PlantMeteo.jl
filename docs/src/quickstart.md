```@meta
CurrentModule = PlantMeteo
```

# Quickstart

This quickstart starts with the most common pain point: getting usable weather from coordinates and dates. The examples below use [`PlantMeteo.DemoAPI()`](@ref), a built-in offline backend for tests and documentation, so the code stays reproducible. It is not a real weather provider. For actual downloads, use the built-in [`OpenMeteo`](@ref) backend (which is the default).

## 1. Download Weather Into A Typed Table

We can use `get_weather` to download weather for a location and period:

```@example quickstart
using PlantMeteo
using Dates
using Statistics

period = Date(2025, 7, 1):Day(1):Date(2025, 7, 2)
weather = get_weather(48.8566, 2.3522, period; api = PlantMeteo.DemoAPI())
weather[1:4]
```

`get_weather` returns a [`Weather`](@ref)-like [`TimeStepTable`](@ref) that you can inspect row-wise or column-wise.

## 2. Inspect The Variables You Will Feed To The Model

[`TimeStepTable`](@ref) is a custom table type that is optimized for weather sampling. It has a row-oriented design, so it is efficient to access rows of weather data for sampling. Each row corresponds to a timestep in the original data, and the columns correspond to the variables at that timestep.

We can inspect the variables in the table by indexing rows like a vector, e.g. `weather[1]` is the first row, which is a `TimeStepRow` struct with fields for each variable:

```@example quickstart
weather[1]
```

You can then inspect the variables in that row by field access, e.g. `weather[1].date` is the date at the first timestep:

```@example quickstart
weather[1].date
```

Similarly, you can access any variable in that row:

```@example quickstart
weather[1].T
```

You can also use a column-oriented design to access variables across all rows like a DataFrame, *e.g.*:


```@example quickstart
weather[1:3, :T]
```

The table also has metadata keys that describe the site and the source of the data:

```@example quickstart
metadatakeys(weather)
```

## 3. Aggregate To One Row Per Day

You can use [`to_daily`](@ref) when you want to aggregate infra-day data into a standard daily weather table with one row per civil day.

```@example quickstart
daily = to_daily(weather)
```

```@example quickstart
length(daily)
```

```@example quickstart
daily[1]
```

## 4. Sample Weather For A Model Time Window

We can use `sample_weather` to sample weather for a model time window. This is useful when you have a model that runs on a different time step than the original data, or when you want to apply a custom reducer over a rolling window.

Let's say we have a model that runs on 24-hour time steps, and we want to sample weather for each 24-hour window. We can use `sample_weather` with a `RollingWindow` to do this:

```@example quickstart
prepared = prepare_weather_sampler(weather)
window = RollingWindow(24.0)
sampled = sample_weather(prepared, 24; window = window)
```

The underlying data structure of `sampled` is the same as `weather`, but the values are now the result of applying the reducer (by default, `mean`) over each 24-hour window. Each row in `sampled` corresponds to a 24-hour window in the original data, and the variables are the aggregated values for that window. You can inspect the variables in `sampled` just like before, e.g. `sampled[1]` is the first sampled row, and `sampled[1].T` is the mean temperature over the first 24-hour window:

```@example quickstart
sampled
```

This sampled row is the aggregation of the previous 24 hourly timesteps:

```@example quickstart
mean(weather[i].T for i in 1:24)
```

## 5. Switch To The Real Open-Meteo Backend

The runnable examples above stay offline on purpose. In real use, replace `PlantMeteo.DemoAPI()` with [`OpenMeteo()`](@ref) (which is the default):

```julia
using PlantMeteo, Dates

period = Date(2025, 7, 1):Day(1):Date(2025, 7, 3)
weather = get_weather(48.8566, 2.3522, period; api=OpenMeteo())
```

## Next Steps

- [Getting Weather Data](getting-weather-data.md): API retrieval and file ingestion
- [Open-Meteo Guide](open-meteo.md): why Open-Meteo is useful and what tradeoffs apply
- [Daily Aggregation](daily-aggregation.md): when `to_daily` is enough
- [Weather Sampling](weather-sampling.md): when you need rolling/calendar windows or custom reducers
