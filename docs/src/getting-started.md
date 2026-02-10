```@meta
CurrentModule = PlantMeteo
```

# Getting Started

This tutorial introduces the package through a realistic first workflow.

## Goal

By the end, you will have:

- loaded weather into a `Weather` table
- inspected the standardized variables
- aggregated fine-step weather into model-friendly steps

## Why This Matters

Most weather workflows fail at the interface between raw data and model expectations:

- columns are named differently across sources
- durations and timestamps are not consistently encoded
- model clocks rarely match source resolution

The examples below show how PlantMeteo addresses these issues step by step.

## 1. Read and Standardize a Weather File

Convert heterogeneous input columns into `Atmosphere`-compatible variables and get a typed weather table (`TimeStepTable{Atmosphere}`) with known fields:

```@example getting_started
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

meteo
```

## 2. Inspect the Data You Will Feed to Models

Each row is an `Atmosphere`. You can get a row by indexing the table with a single index:

```@example getting_started
first_row = meteo[1]
first_row
```

And because PlantMeteo implements the Tables.jl interface, table columns are easy to inspect and manipulate like a DataFrame.
For example to get the temperature column as a vector:

```@example getting_started
meteo.T
```

## 3. Sample Weather to Match a Model Time Step

Sometimes models require weather at a coarser time step than the source data. For example, you may have hourly weather but want daily values for a crop model. PlantMeteo's sampling functions let you aggregate weather from source resolution to model resolution, and get an aggregated `Atmosphere` row per query step.

For example we can build a fake 2-day hourly series and sample it to get a daily-like `Atmosphere` for the 24th hour, using a rolling 24-source-step window:

```@example getting_started
# Build a longer hourly series for sampling demonstrations.
base = DateTime(2025, 1, 1)
meteo_hourly = Weather([
    Atmosphere(
        date = base + Hour(i),
        duration = Hour(1),
        T = 10.0 + i,
        Wind = 1.0,
        Rh = 0.55,
        P = 100.0,
        Ri_SW_f = 200.0
    )
    for i in 0:47
])

prepared = prepare_weather_sampler(meteo_hourly)
window = RollingWindow(24.0)  # trailing 24-source-step window
sampled = sample_weather(prepared, 24; window = window)

# Get the temperature from the sampled row, which is a daily-averaged value of the 24 hourly source steps:
(;sampled.duration, sampled.date, sampled.T)
```

This value is the mean of the 24 hourly temperatures from the source data, which matches our expectation for a daily-like sample:

```@example getting_started
using Statistics
mean(meteo_hourly[i].T for i in 1:24)
```

## 4. Precompute Sampling for Whole Runs

Avoid repeated sampling work in long simulation loops, and get a cached sampled table for each requested sampling window:

```@example getting_started
tables = materialize_weather(prepared; windows = [window])
daily_like = tables[window]

(length(daily_like), daily_like[24].T ≈ sampled.T, length(meteo_hourly))
```

## 5. Override Default Sampling Rules (Optional)

Encode model-specific aggregation rules per variable. Transforms are normalized and applied for the current call:

```@example getting_started
custom_transforms = (
    T = MeanWeighted(),
    Tmax = (source = :T, reducer = MaxReducer()),
    Tsum = (source = :T, reducer = SumReducer())
)

custom_row = sample_weather(prepared, 24; window = window, transforms = custom_transforms)
(custom_row.T, custom_row.Tmax, custom_row.Tsum)
```

## Next Steps

- [Weather Data Sources](weather-apis.md): deeper look at file/API ingestion and export.
- [Weather Sampling](weather-sampling.md): windows, reducers, transforms, and caching strategy.
- [API](API.md): full reference for all exported symbols.
