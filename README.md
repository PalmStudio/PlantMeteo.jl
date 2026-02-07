# PlantMeteo

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://PalmStudio.github.io/PlantMeteo.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://PalmStudio.github.io/PlantMeteo.jl/dev)
[![Build Status](https://github.com/PalmStudio/PlantMeteo.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/PalmStudio/PlantMeteo.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/PalmStudio/PlantMeteo.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/VEZY/PlantMeteo.jl)

WIP package to compute and get meteorological or climatic data related to plant growth.

# Road map

- [x] Use an efficient structure for the meteo data (TimeStepTable{Atmosphere})
- [x] Add a generic interface for the weather forecast and history APIs
- [x] Add one meteo API (open-meteo)
- [x] Add a function for integrating sub-daily data into daily data, and check that sum(durations) == 24 hours
- [x] Add function to write meteo data (avoiding to write computed variables such as ρ or λ)
- [ ] Add more APIs
- [ ] Add functions for computing sub-daily data from daily data 
- [ ] TimeStepTable: Ensure that we don't copy the data when transforming to e.g. `DataFrame`. Related to [#19](https://github.com/PalmStudio/PlantMeteo.jl/issues/19).
- [ ] TimeStepTable: Use views when indexing for better performance ? Or at least show examples.
- [ ] write_weather: don't transform into DataFrame for selecting columns? If so, implement a select of use the one from `TableOperations.jl`. Related to [#19](https://github.com/PalmStudio/PlantMeteo.jl/issues/19).

  