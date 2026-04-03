```@meta
CurrentModule = PlantMeteo
```

# PlantMeteo

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://PalmStudio.github.io/PlantMeteo.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://PalmStudio.github.io/PlantMeteo.jl/dev)
[![Build Status](https://github.com/PalmStudio/PlantMeteo.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/PalmStudio/PlantMeteo.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/PalmStudio/PlantMeteo.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/VEZY/PlantMeteo.jl)

`PlantMeteo` helps plant-model workflows move from raw meteorological inputs to model-ready weather tables. It is designed for two common starting points: you have coordinates and dates but no weather file yet, or you already have weather data but it needs to be standardized, checked, aggregated, or exported.

## Start Here

- Start with [`get_weather`](@ref) if you do not already have a cleaned weather file.
- Start with [`read_weather`](@ref) if you already have station, archive, or project weather data.
- Use [`to_daily`](@ref) when you want one row per civil day with standard daily summaries.
- Use [`prepare_weather_sampler`](@ref) and [`sample_weather`](@ref) when your model needs rolling or calendar windows, custom reducers, or cached repeated queries.

## Why This Package Exists

Plant models rarely receive weather in the exact format they need:

- station files use different column names and units
- downloaded weather often comes through provider-specific schemas
- source timesteps rarely match the timestep expected by the model

`PlantMeteo` gives you a consistent weather table abstraction, a small API interface, and tools to aggregate or sample weather into the form your model actually uses.

## Fastest Path: Get Weather From Coordinates And Dates

If your first problem is "I need usable weather quickly", start with [`get_weather`](@ref) and the built-in [`OpenMeteo`](@ref) backend. It is the earliest path in this documentation because it removes one of the most painful setup steps in many modeling workflows.

Open-Meteo is a practical default because it provides:

- simple coordinate-based access
- hourly meteorological variables
- recent forecasts and older archive data through one interface
- no API key friction for exploratory and research use

See [Open-Meteo Guide](open-meteo.md) for how PlantMeteo uses it, why it is useful, and where its limits are.

## Second Path: Read And Standardize Local Files

If you already have weather data, [`read_weather`](@ref) maps source-specific column names and units to PlantMeteo's canonical variables and returns a typed weather table. This path is usually best for station exports, legacy project files, and curated datasets that you want to keep under your own control.

## Main Capabilities

- [`TimeStepTable`](@ref), [`Weather`](@ref), and [`Atmosphere`](@ref) for typed weather storage and inspection
- [`get_weather`](@ref) and [`OpenMeteo`](@ref) for API retrieval
- [`read_weather`](@ref) and [`write_weather`](@ref) for ingestion and export
- [`to_daily`](@ref) for daily aggregation
- [`prepare_weather_sampler`](@ref), [`sample_weather`](@ref), and [`materialize_weather`](@ref) for model-aligned weather sampling

## Installation

From the Julia package REPL, run `add PlantMeteo`.
Then load it with `using PlantMeteo`.

## Documentation Map

- [Quickstart](quickstart.md): first runnable workflow with an offline demo API
- [Getting Weather Data](getting-weather-data.md): API and file-based entry paths
- [Open-Meteo Guide](open-meteo.md): why Open-Meteo is useful and what caveats apply
- [Core Concepts](core-concepts.md): `Atmosphere`, `Weather`, `TimeStepTable`, metadata, and units
- [Daily Aggregation](daily-aggregation.md): one-row-per-day summaries with `to_daily`
- [Weather Sampling](weather-sampling.md): rolling/calendar windows and custom reducers
- [Read/Write Round Trip](read-write-round-trip.md): export cleaned weather tables
- [Reference](reference.md): grouped API reference
