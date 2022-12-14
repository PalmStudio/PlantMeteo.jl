"""
    Weather(D <: AbstractArray{<:AbstractAtmosphere}[, metadata])
    Weather(df::DataFrame[, metadata])

Defines the weather, *i.e.* the local conditions of the Atmosphere for one or more time-steps.
Each time-step is described using the [`Atmosphere`](@ref) structure, and the resulting structure
is a `TimeStepTable`.

The simplest way to instantiate a `Weather` is to use a `DataFrame` as input.

The `DataFrame` should be formated such as each row is an observation for a given time-step
and each column is a variable. The column names should match exactly the field names of the
[`Atmosphere`](@ref) structure, `i.e.`:

```@example
fieldnames(Atmosphere)
```

## See also

- the [`Atmosphere`](@ref) structure
- the [`read_weather`](@ref) function to read Archimed-formatted meteorology data.

## Examples

```julia
# Example of weather data defined by hand (cumbersome):
w = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ],
    (
        site = "Test site",
        important_metadata = "this is important and will be attached to our weather data"
    )
)

# Example using a DataFrame, that you would usually import from a file:
using CSV, DataFrames
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv")
df = CSV.read(file, DataFrame; header=5, datarow = 6)
# Select and rename the variables:
select!(df, :date, :VPD, :temperature => :T, :relativeHumidity => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)
df[!,:duration] .= 1800 # Add the time-step duration, 30min

# Make the weather, and add some metadata:
Weather(df, (site = "Aquiares", file = file))
```
"""
function Weather(data::T, metadata::S=NamedTuple()) where {T<:AbstractArray{<:AbstractAtmosphere},S<:NamedTuple}
    TimeStepTable(data, metadata)
end

function Weather(df::DataFrames.DataFrame, mt::S=NamedTuple()) where {S<:NamedTuple}
    Weather([Atmosphere(; i...) for i in eachrow(df)], mt)
end