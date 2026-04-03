# PlantMeteo

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://PalmStudio.github.io/PlantMeteo.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://PalmStudio.github.io/PlantMeteo.jl/dev)
[![Build Status](https://github.com/PalmStudio/PlantMeteo.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/PalmStudio/PlantMeteo.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/PalmStudio/PlantMeteo.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/VEZY/PlantMeteo.jl)

`PlantMeteo` helps plant-model workflows get from raw weather inputs to model-ready meteorological tables. It gives you one set of tools to download weather from coordinates and dates, standardize local files, inspect typed weather rows, aggregate to daily summaries, sample to model-specific time windows, and write cleaned weather back to disk.

## Installation

From the Julia package REPL:

```julia
] add PlantMeteo
```

Then load it with:

```julia
using PlantMeteo
```

## Fastest Path: Get Weather From Coordinates And Dates

If you do not already have cleaned station files, start with the API interface. `PlantMeteo` exposes [`get_weather`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.get_weather) and ships with an [`OpenMeteo`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.OpenMeteo) backend so you can go from coordinates and dates to a usable weather table quickly:

```julia
using PlantMeteo, Dates

period = Date(2025, 7, 1):Day(1):Date(2025, 7, 3)
weather = get_weather(48.8566, 2.3522, period; api=OpenMeteo())

weather[1]
```

Open-Meteo is a good default when you want broad geographic coverage, hourly variables, and minimal setup. PlantMeteo uses the Open-Meteo forecast endpoint for recent/future data and its historical archive endpoint for older periods, which makes it practical for both forward-looking runs and retrospective analyses. See the [Open-Meteo guide](https://palmstudio.github.io/PlantMeteo.jl/stable/open-meteo/) for strengths, limits, and caveats.

## Second Path: Read And Standardize Local Weather Files

If you already have station data, project weather files, or archived CSVs, use [`read_weather`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.read_weather) to map source-specific columns and units into PlantMeteo's canonical variables:

```julia
using PlantMeteo, Dates

file = joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv")

weather = read_weather(
    file,
    :temperature => :T,
    :relativeHumidity => (x -> x ./ 100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)
```

## What PlantMeteo Gives You

- A typed weather table built on [`TimeStepTable`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.TimeStepTable), [`Weather`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.Weather), and [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.Atmosphere)
- API retrieval through [`get_weather`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.get_weather)
- Local file ingestion and export through [`read_weather`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.read_weather) and [`write_weather`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.write_weather)
- One-row-per-day summaries with [`to_daily`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.to_daily)
- Model-aligned weather sampling with [`prepare_weather_sampler`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.prepare_weather_sampler), [`sample_weather`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.sample_weather), and [`materialize_weather`](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/#PlantMeteo.materialize_weather)

## Documentation

- [Home](https://palmstudio.github.io/PlantMeteo.jl/stable/)
- [Quickstart](https://palmstudio.github.io/PlantMeteo.jl/stable/quickstart/)
- [Getting Weather Data](https://palmstudio.github.io/PlantMeteo.jl/stable/getting-weather-data/)
- [Open-Meteo Guide](https://palmstudio.github.io/PlantMeteo.jl/stable/open-meteo/)
- [Core Concepts](https://palmstudio.github.io/PlantMeteo.jl/stable/core-concepts/)
- [Daily Aggregation](https://palmstudio.github.io/PlantMeteo.jl/stable/daily-aggregation/)
- [Weather Sampling](https://palmstudio.github.io/PlantMeteo.jl/stable/weather-sampling/)
- [Read/Write Round Trip](https://palmstudio.github.io/PlantMeteo.jl/stable/read-write-round-trip/)
- [Reference](https://palmstudio.github.io/PlantMeteo.jl/stable/reference/)
  
