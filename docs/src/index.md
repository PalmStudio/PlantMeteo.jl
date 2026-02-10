```@meta
CurrentModule = PlantMeteo
```

# PlantMeteo

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://PalmStudio.github.io/PlantMeteo.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://PalmStudio.github.io/PlantMeteo.jl/dev)
[![Build Status](https://github.com/PalmStudio/PlantMeteo.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/PalmStudio/PlantMeteo.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/PalmStudio/PlantMeteo.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/VEZY/PlantMeteo.jl)

## What Problem This Package Solves

Plant models often consume weather data from very different sources:

- station files with inconsistent column names and units
- API data with provider-specific schemas
- time steps that do not match your model clock (hourly input, daily model, multi-rate simulation)

`PlantMeteo` gives you a single workflow to standardize, inspect, and aggregate weather data into a structure that downstream plant models can use directly.

## What You Get

- A weather table abstraction with [`TimeStepTable`](@ref), [`Weather`](@ref), and [`Atmosphere`](@ref)
- File ingestion and export with [`read_weather`](@ref) and [`write_weather`](@ref)
- API retrieval through [`get_weather`](@ref) with the built-in [`OpenMeteo`](@ref) backend
- A configurable sampler for model-aligned aggregation with [`prepare_weather_sampler`](@ref), [`sample_weather`](@ref), and [`materialize_weather`](@ref)

## Who This Is For

- model developers who need robust weather preprocessing before simulation
- researchers combining historical files and forecast APIs
- package authors who want to plug custom weather providers behind one interface

## Documentation Map

- Start with [Getting Started](getting-started.md)
- Continue with in-depth guides:
  - [Weather Data Sources](weather-apis.md)
  - [Weather Sampling](weather-sampling.md)
- Use [API](API.md) for full reference

## Installation

From the Julia package REPL, run `add PlantMeteo`.
Then load it with `using PlantMeteo`.

## Projects Using PlantMeteo

- [PlantSimEngine.jl](https://github.com/VEZY/PlantSimEngine.jl)
- [PlantBiophysics.jl](https://github.com/VEZY/PlantBiophysics.jl)
- [XPalm](https://github.com/PalmStudio/XPalm.jl)
