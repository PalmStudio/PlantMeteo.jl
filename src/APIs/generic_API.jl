"""
    AbstractAPI

An abstract type for APIs. This is used to define the API to use for the weather forecast.
You can get all available APIs using `subtype(AbstractAPI)`.
"""
abstract type AbstractAPI end


"""
    get_weather(lat, lon, period::Dates.Date; api::DataType=OpenMeteo, sink=TimeStepTable)

Returns the weather forecast for a given location and time using a weather API.

# Arguments
- `lat::Float64`: Latitude of the location
- `lon::Float64`: Longitude of the location
- `period::Union{StepRange{Date, Day}, Vector{Dates.Date}}`: Period of the forecast
- `api::DataType=OpenMeteo`: API to use for the forecast.
- `sink::DataType=TimeStepTable`: Type of the output. Default is `TimeStepTable`, but it
can be any type that implements the `Tables.jl` interface, such as `DataFrames`.

# Details

We can get all available APIs using `subtype(AbstractAPI)`.
Please keep in mind that the default [`OpenMeteo`](@ref) API is not free for commercial use, and that you should
use it responsibly.

# Examples

```julia
using PlantMeteo, Dates
# Forecast for today and tomorrow:
period = today():Day(1):today()+Dates.Day(1) 
w = get_weather(48.8566, 2.3522, period)
```
"""
function get_weather(lat, lon, period::P; api::AbstractAPI=OpenMeteo(), sink=TimeStepTable) where {P<:Union{StepRange{Dates.Date,Dates.Day},Vector{Dates.Date}}}
    # Get the weather forecast from open-meteo.com
    tst = get_forecast(api, lat, lon, period)

    # Get the forecasted weather variables
    # t_min = forecast["t_min"]
    # t_max = forecast["t_max"]
    # rh_min = forecast["rh_min"]
    # rh_max = forecast["rh_max"]
    # wind = forecast["wind"]

    # # Compute the average temperature
    # t_mean = (t_min + t_max) / 2

    # # Compute the average relative humidity
    # rh_mean = (rh_min + rh_max) / 2

    # # Compute the vapor pressure deficit
    # vpd = vapor_pressure_deficit(t_mean, rh_mean)

    # Use the sink:
    if sink == TimeStepTable
        # tst is already a TimeStepTable so we just return it
        return tst
    else
        return sink(tst)
    end
end