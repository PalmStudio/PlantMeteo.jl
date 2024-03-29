"""
    AbstractAPI

An abstract type for APIs. This is used to define the API to use for the weather forecast.
You can get all available APIs using `subtype(AbstractAPI)`.
"""
abstract type AbstractAPI end

"""
    get_weather(lat, lon, period::Union{StepRange{Date, Day}, Vector{Dates.Date}}; api::DataType=OpenMeteo, sink=TimeStepTable, kwargs...)

Returns the weather forecast for a given location and time using a weather API.

# Arguments

- `lat::Float64`: Latitude of the location in degrees
- `lon::Float64`: Longitude of the location in degrees
- `period::Union{StepRange{Date, Day}, Vector{Dates.Date}}`: Period of the forecast
- `api::DataType=OpenMeteo`: API to use for the forecast.
- `sink::DataType=TimeStepTable`: Type of the output. Default is `TimeStepTable`, but it
can be any type that implements the `Tables.jl` interface, such as `DataFrames`.
- `kwargs...`: Additional keyword arguments that are passed to the API

# Details

We can get all available APIs using `subtype(AbstractAPI)`.
Please keep in mind that the default [`OpenMeteo`](@ref) API is not free for commercial use, and that you should
use it responsibly.

# Examples

```julia
using PlantMeteo, Dates
# Forecast for today and tomorrow:
period = [today(), today()+Dates.Day(1)]
w = get_weather(48.8566, 2.3522, period)
```
"""
function get_weather(lat, lon, period::P; api::AbstractAPI=OpenMeteo(), sink=TimeStepTable, kwargs...) where {P<:Union{StepRange{Dates.Date,Dates.Day},Vector{Dates.Date}}}

    @assert lat >= -90 && lat <= 90 "Latitude must be between -90 and 90"
    @assert lon >= -180 && lon <= 180 "Longitude must be between -180 and 180"

    # Get the weather forecast from the API:
    tst = get_forecast(api, lat, lon, period; kwargs...)

    # Use the sink:
    if sink == TimeStepTable
        # tst is already a TimeStepTable so we just return it
        return tst
    else
        return sink(tst)
    end
end