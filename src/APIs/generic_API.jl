"""
    AbstractAPI

Abstract supertype for weather-download backends used by [`get_weather`](@ref).

Implement a subtype of `AbstractAPI` plus a corresponding `get_forecast` method when you want to
plug a custom weather provider into PlantMeteo without changing the downstream workflow.
"""
abstract type AbstractAPI end

"""
    DemoAPI()

Offline weather backend bundled with PlantMeteo for documentation, tests, and examples.

`DemoAPI` is not a real weather provider. It returns a deterministic synthetic hourly weather
series from latitude, longitude, and date range inputs so examples can be copied into a REPL and
run without network access. For real weather downloads, use [`OpenMeteo()`](@ref), which remains
the default live backend for [`get_weather`](@ref).
"""
struct DemoAPI <: AbstractAPI end

function get_forecast(::DemoAPI, lat, lon, period; verbose=true, kwargs...)
    hours = Dates.DateTime(period[1]):Dates.Hour(1):(Dates.DateTime(period[end]) + Dates.Hour(23))
    rows = map(hours) do t
        h = Dates.hour(t)
        solar = h in 6:18 ? 650.0 * sin(pi * (h - 6) / 12) : 0.0
        day_offset = Dates.day(t) - Dates.day(period[1])
        Atmosphere(
            date=t,
            duration=Dates.Hour(1),
            T=20.0 + 5.0 * sin(2pi * h / 24) + 0.8 * day_offset,
            Wind=1.2 + 0.1 * cos(2pi * h / 24),
            Rh=0.65 - 0.15 * sin(2pi * h / 24),
            P=101.3,
            Precipitations=h in (5, 6, 17) ? 0.4 : 0.0,
            Ri_SW_f=solar,
            Cₐ=415.0
        )
    end
    return TimeStepTable(rows, (latitude=lat, longitude=lon, source="demo-api"))
end

"""
    get_weather(lat, lon, period; api=OpenMeteo(), sink=TimeStepTable, kwargs...)

Download weather for a location and date range through a PlantMeteo API backend.

This is usually the first function to use when you have coordinates and dates but no cleaned weather
file yet. The result is a weather table that can then be inspected, aggregated with [`to_daily`](@ref),
sampled with [`sample_weather`](@ref), or written to disk with [`write_weather`](@ref).

# Arguments

- `lat`: latitude in degrees.
- `lon`: longitude in degrees.
- `period`: date range as `StepRange{Date,Day}` or `Vector{Date}`.
- `api`: backend implementing `get_forecast`. Defaults to [`OpenMeteo()`](@ref).
- `sink`: output sink. Defaults to [`TimeStepTable`](@ref), but any compatible sink can be used.
- `kwargs...`: forwarded to the backend.

# Notes

- The documentation site uses [`DemoAPI`](@ref), a built-in offline backend for tests and demos.
- Real Open-Meteo calls require network access and should be treated as live external requests.

# Example

```julia
using PlantMeteo, Dates

period = Date(2025, 7, 1):Day(1):Date(2025, 7, 3)
weather = get_weather(48.8566, 2.3522, period; api=OpenMeteo())
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
