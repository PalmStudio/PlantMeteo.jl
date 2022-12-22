module PlantMeteo

import Dates
import YAML, CSV
import Tables
import Term # for pretty printing the TimeStepTable
import HTTP, JSON # for the open-meteo API

include("structs/defaults.jl")
include("structs/constants.jl")
include("computations/variables_computations.jl")
include("computations/emissivity.jl")
include("structs/atmosphere.jl")
include("structs/TimeStepTable.jl")
include("computations/duration.jl")
include("structs/weather.jl")
include("APIs/transform_table.jl")
include("APIs/generic_API.jl")
include("APIs/read_weather.jl")
include("APIs/open-meteo.jl")
include("computations/conversions.jl")

export Atmosphere, TimeStepTable, Constants, Weather
export atmosphere_emissivity, vapor_pressure
export e_sat, air_density, latent_heat_vaporization
export psychrometer_constant
export rh_from_vpd, rh_from_e, vpd
export metadata
export read_weather
export get_forecast
export OpenMeteo
export get_weather

end
