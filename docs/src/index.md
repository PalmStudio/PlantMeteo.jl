```@meta
CurrentModule = PlantMeteo
```

# PlantMeteo

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://PalmStudio.github.io/PlantMeteo.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://PalmStudio.github.io/PlantMeteo.jl/dev)
[![Build Status](https://github.com/PalmStudio/PlantMeteo.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/PalmStudio/PlantMeteo.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/PalmStudio/PlantMeteo.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/VEZY/PlantMeteo.jl)

## Overview

`PlantMeteo` is for everything related to meteorological/climatic data related to plant growth. 

The package gives users access to useful and efficient structures, functions for reading and computing data and easy connection to weather APIs:

- [`TimeStepTable`](@ref) to define efficient tables
- [`Atmosphere`](@ref) to automatically compute atmosphere-related variables from a set of variables
- [`Constants`](@ref) that provide default values for physical constants (*e.g.* the universal gas constant or the latent heat of vaporization of water)
- helper functions such as [`vapor_pressure`](@ref), [`e_sat`](@ref), [`air_density`](@ref), [`psychrometer_constant`](@ref) or [`latent_heat_vaporization`](@ref)
- easy download of weather data from renowned APIs such as [open-meteo.com](https://open-meteo.com/en) with [`OpenMeteo`](@ref)
- and a framework to easily add more APIs thanks to [`get_weather`](@ref)

## Installation

To install the package, enter the Julia package manager mode by pressing `]` in the REPL, and execute the following command:

```julia
add PlantMeteo
```

To use the package, execute this command from the Julia REPL:

```julia
using PlantMeteo
```

## Projects that use PlantMeteo

Take a look at these projects that use PlantSimEngine:

- [PlantSimEngine.jl](https://github.com/VEZY/PlantSimEngine.jl)
- [PlantBiophysics.jl](https://github.com/VEZY/PlantBiophysics.jl)
- [XPalm](https://github.com/PalmStudio/XPalm.jl)

## Make it yours 

The package is developed so anyone can easily integrate it into workflows and packages. For example [`TimeStepTable`](@ref) can be used for any type of data. See the implementation of `TimeStepTable{Status}` in [PlantSimEngine.jl](https://github.com/VEZY/PlantSimEngine.jl).

If you develop such tools and it is not on the list yet, please make a PR or contact me so we can add it! 😃